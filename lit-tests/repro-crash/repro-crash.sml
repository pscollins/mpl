structure Scheduler =
struct

  fun arraySub (a, i) = Array.sub (a, i)
  fun arrayUpdate (a, i, x) = Array.update (a, i, x)
  fun vectorSub (v, i) = Vector.sub (v, i)

  val maxCCDepth = 1
  val P = 1
  fun myWorkerId ()  = MLton.Parallel.processorNumber ()

  fun die strfn = OS.Process.exit OS.Process.failure
  fun die' () = OS.Process.exit OS.Process.failure

  type gcstate = MLton.Pointer.t
  val gcstate = _prim "GC_state": unit -> gcstate;

  datatype TokenPolicy =
      TokenPolicyFair (* 0w0 *)

  val traceSchedSpawn = _import "GC_Trace_schedSpawn" private: gcstate -> unit; o gcstate
  val traceSchedJoin = _import "GC_Trace_schedJoin" private: gcstate -> unit; o gcstate
  val traceSchedJoinFast = _import "GC_Trace_schedJoinFast" private: gcstate -> unit; o gcstate

  structure Queue = DequeABP (*ArrayQueue*)
  structure Thread = MLton.Thread.Basic

  val primSporkFair' =
      _prim "spork_fair"
        : ('aa -> 'ar)		(* body     *)
        * 'aa			(* body arg *)
        * ('ba * 'd -> 'br)	(* spwn     *)
        * 'ba			(* spwn arg *)
        * ('ar -> 'c)		(* seq      *)
        * ('ar * 'd -> 'c)	(* sync     *)
        * (exn -> 'c)		(* exn seq  *)
        * (exn * 'd -> 'c)	(* exn sync *)
        -> 'c;
  fun __inline_always__ primSporkFair (body, spwn, seq, sync, exnseq, exnsync) =
      __inline_always__ primSporkFair' (body, (), spwn, (), seq, sync, exnseq, exnsync)
  
  val primForkThreadAndSetData = _prim "spork_forkThreadAndSetData": Thread.t * 'a -> Thread.p;

  fun assertAtomic msg x = ()

  val threadSwitchEndAtomic = Thread.switchTo

  structure HM = MLton.HM
  structure HH = MLton.Thread.HierarchicalHeap
  type hh_address = Word64.word
  type gctask_data = Thread.t * (hh_address ref)

  structure DE = MLton.Thread.Disentanglement

  fun decrementHitsZero (x : int ref) : bool = true

  datatype gc_joinpoint =
    GCJ of {gcTaskData: gctask_data option, tidRight: Word64.word}
    (** The fact that the gcTaskData is an option here is a questionable
      * hack... the data will always be SOME. But unwrapping it may affect
      * how many allocations occur when spawning a gc task, which in turn
      * affects the GC snapshot, which is already murky.
      *)

  datatype 'a joinpoint =
    J of
      { leftSideThread: Thread.t
      , rightSideThread: Thread.t option ref
      , rightSideResult: 'a Result.t option ref
      , incounter: int ref
      , tidRight: Word64.word
      , spareHeartbeatsGiven: Heartbeat.token_count
      , tokenPolicy: TokenPolicy
      , gcj: gc_joinpoint option
      }


  (* ========================================================================
   * DEBUGGING
   *)

  val doDebugMsg = false

  val printLock : Word32.word ref = ref 0w0
  val _ = MLton.Parallel.Deprecated.lockInit printLock

  fun assertTokenInvariants thread msg = ()
  (* ========================================================================
   * TASKS
   *)

  (* In the case of NormalTask and NewThread, the Word64 is the decheck id that
   * we should use for the chunks allocated for these tasks.
   *)
  datatype task =
    NormalTask of (unit -> unit) * Word64.word * int
  | NewThread of Thread.p * Word64.word * int
  | Continuation of Thread.t * int
  | GCTask of gctask_data

  (* ========================================================================
   * STATS
   *)

  val numEagerSpawns = Array.array (P, 0)


  fun addEagerSpawns d =
    let
      val p = myWorkerId ()
      val c = arraySub (numEagerSpawns, p)
    in
      arrayUpdate (numEagerSpawns, p, c+d)
    end

  (** ========================================================================
    * MAXIMUM FORK DEPTHS
    *)

  (* ========================================================================
   * CHILD TASK PROTOTYPE THREAD
   *
   * this widget makes it possible to create new "user" threads by copying
   * the prototype thread, which immediately pulls a task out of the
   * current worker's task-box and then executes it.
   *)

  (* ========================================================================
   * SCHEDULER LOCAL DATA
   *)

  type worker_local_data =
    { queue : task Queue.t
    , schedThread : Thread.t option ref
    , gcTask: gctask_data option ref
    }

  fun wldInit p : worker_local_data =
    { queue = Queue.new ()
    , schedThread = ref NONE
    , gcTask = ref NONE
    }

  val workerLocalData = Vector.tabulate (P, wldInit)

  fun setGCTask p data =
    #gcTask (vectorSub (workerLocalData, p)) := data

  fun getGCTask p =
    ! (#gcTask (vectorSub (workerLocalData, p)))

  fun getSchedThread () =
    let
      val myId = myWorkerId ()
      val {schedThread, ...} = vectorSub (workerLocalData, myId)
    in
      HM.refDerefNoBarrier schedThread
    end

  fun setQueueDepth p d =
    let
      val {queue, ...} = vectorSub (workerLocalData, p)
    in
      Queue.setDepth queue d
    end

  fun trySteal p =
    let
      val {queue, ...} = vectorSub (workerLocalData, p)
    in
      Queue.tryPopTop queue
    end

  fun communicate () = ()

  fun push (x): unit =
    let
      val myId = myWorkerId ()
      val {queue, ...} = vectorSub (workerLocalData, myId)
    in
      Queue.pushBot queue x
    end

  fun clear () = ()

  fun pop (): task option =
    let
      val myId = myWorkerId ()
      val {queue, ...} = vectorSub (workerLocalData, myId)
    in
      Queue.popBot queue
    end

  fun popDiscard () =
    case pop () of
      NONE => false
    | SOME _ => true

  fun returnToSchedEndAtomic () = ()

  (* ========================================================================
   * SPORK JOIN
   *)

  structure SporkJoin =
  struct

    fun spawnGC interruptedThread : gc_joinpoint option =
      let
        val thread = Thread.current ()
        val depth = HH.getDepth thread
      in
        if depth > maxCCDepth then
          NONE
        else
          let
            (** SAM_NOTE: atomic begin/end not needed here, becuase this is
              * already run in signal handler.
              *)

            val heapId = ref (HH.getRoot thread)
            val gcTaskTuple = (interruptedThread, heapId)
            val gcTaskData = SOME gcTaskTuple
            val gcTask = GCTask gcTaskTuple
            val _ = push gcTask
          in
             NONE
          end
      end


    (* runs in signal handler *)
    fun doSpawn (interruptedLeftThread: Thread.t) : unit =
      let
        val gcj = spawnGC interruptedLeftThread
        val _ = assertAtomic "spawn after spawnGC" 1

        val thread = Thread.current ()
        val depth = HH.getDepth thread

        (* We use a ref here instead of using rightSideThread directly.
         * The rightSideThread is a Thread.p (it doesn't have a heap yet).
         * The thief will convert it into a Thread.t and give it a heap,
         * and then write it into this slot. *)
        val rightSideThreadSlot = ref (NONE: Thread.t option)
        val rightSideResult = ref (NONE: Universal.t Result.t option)
        val incounter = ref 2

        val tidParent = DE.decheckGetTid thread
        val (tidLeft, tidRight) = DE.decheckFork ()

        val giveTokens = Heartbeat.halfOfCurrent ()
        val jp =
          J { leftSideThread = interruptedLeftThread
            , rightSideThread = rightSideThreadSlot
            , rightSideResult = rightSideResult
            , incounter = incounter
            , tidRight = tidRight
            , spareHeartbeatsGiven = giveTokens
            , tokenPolicy = TokenPolicyFair
            , gcj = gcj
            }

        (* this sets the join for both threads (left and right) *)
        val rightSideThread =
            primForkThreadAndSetData (interruptedLeftThread, jp)
      in
        ()
      end


    (* runs in signal handler *)
    fun maybeSpawn youngestOptimization (interruptedLeftThread: Thread.t) : bool =
        (doSpawn interruptedLeftThread ; true)

    fun maybeSpawnFunc {allowCGC: bool} (g: unit -> 'a) : 'a joinpoint option = NONE

    (** Must be called in an atomic section. Implicit atomicEnd() *)
    fun syncEndAtomic
        (doClearSuspects: Thread.t * int -> unit)
        (J {rightSideThread, rightSideResult, incounter, tidRight, gcj, spareHeartbeatsGiven, tokenPolicy, ...} : 'a joinpoint)
        : 'a Result.t option
      = 
      let
        val thread = Thread.current ()
        val depth = HH.getDepth thread
        val _ = decrementHitsZero incounter
        val _ = HM.refDerefNoBarrier rightSideThread

        val result =
            if popDiscard () then
               let
                  val _ = HH.joinIntoParentBeforeFastClone
                              {thread=thread, newDepth=depth, tidLeft=tidRight, tidRight=tidRight}
               in
                  NONE
               end
            else NONE
      in
        NONE
      end


    and maybeParClearSuspectsAtDepth (t, d) = ()

    fun sched_package () = 
        { syncEndAtomic = syncEndAtomic maybeParClearSuspectsAtDepth
      , maybeSpawn = maybeSpawn
      , setQueueDepth = setQueueDepth
      , returnToSchedEndAtomic = returnToSchedEndAtomic
      , tryConsumeSpareHeartbeats = Heartbeat.consumeSpare
      , addEagerSpawns = addEagerSpawns
      , assertAtomic = assertAtomic
      , error = (fn s => die (fn _ => s)) : string -> unit
      }

    (* ===================================================================
     * spork definition
     *)

    fun __inline_always__ tryPromoteNow yo =
      ( Thread.atomicBegin ()
      ; if
          Heartbeat.enoughToSpawn () andalso
          #maybeSpawn (sched_package ()) yo (Thread.current ())
        then
          #addEagerSpawns (sched_package ()) 1
        else
          ()
      ; Thread.atomicEnd ()
      )

    type ('a, 'c) sporkT =
           (unit -> 'a)
         * (unit * Universal.t joinpoint -> unit)
         * ('a -> 'c)
         * ('a * Universal.t joinpoint -> 'c)
         * (exn -> 'c)
         * (exn * Universal.t joinpoint -> 'c)
         -> 'c

    fun __inline_always__ sporkBase (primSpork: ('a, 'c) sporkT,
                                     body: unit -> 'a,
                                     spwn: unit -> 'b,
                                     seq: 'a -> 'c,
                                     sync: 'a * 'b -> 'c,
                                     unstolen: 'a -> 'c): 'c =
      let
        val (inject, project) = Universal.embed ()

        fun __inline_always__ body' (): 'a =
            ((if not (Heartbeat.enoughToSpawn ()) then () else tryPromoteNow {youngestOptimization = true});
             body ())

        fun spwn' ((), J jp): unit =
          let
            val _ = #assertAtomic (sched_package ()) "spork rightside begin" 1

            val thread = Thread.current ()
            val depth = HH.getDepth thread

            val spwnr = Result.result (inject o spwn)

            val depth' = HH.getDepth (Thread.current ())
          in
            #rightSideThread jp := SOME thread;
            #rightSideResult jp := SOME spwnr;

            if decrementHitsZero (#incounter jp) then
              ( ()
              ; #setQueueDepth (sched_package ()) (myWorkerId ()) depth
                (** Atomic 1 *)
              ; Thread.atomicBegin ()
              ; #assertAtomic (sched_package ()) "spork rightside switch-to-left" 2
              ; threadSwitchEndAtomic (#leftSideThread jp)
              )
            else
              ( #assertAtomic (sched_package ()) "spork rightside before returnToSched" 1
              ; #returnToSchedEndAtomic (sched_package ()) ()
              )
          end

        fun __inline_always__ seq' (bodyr: 'a): 'c =
            __inline_always__ seq bodyr

        fun __inline_always__ sync' (bodyr: 'a, jp: Universal.t joinpoint): 'c =
          let
            val spwnrOpt = #syncEndAtomic (sched_package ()) jp
          in
            case spwnrOpt of
              (* spwn was unstolen *)
                _ => unstolen bodyr
          end

        fun __inline_always__ exnseq' (e: exn): 'c = raise e

        fun __inline_always__ exnsync' (e: exn, jp: Universal.t joinpoint): 'c =
            let val _ = #syncEndAtomic (sched_package ()) jp
            in
              raise e
            end
      in
        __inline_always__ primSpork (body', spwn', seq', sync', exnseq', exnsync')
      end

    fun __inline_always__ spork
                          {body: unit -> 'a,
                           spwn: unit -> 'b,
                           seq: 'a -> 'c,
                           sync: 'a * 'b -> 'c,
                           unstolen: ('a -> 'c) option} =
          sporkBase (primSporkFair, body, spwn, seq, sync, seq)
  end


end
structure ForkJoin0 =
struct
  val spork = Scheduler.SporkJoin.spork

  fun par (f: unit -> 'a, g: unit -> 'b): 'a * 'b =
      spork {
        body = f,
        spwn = g,
        seq  = fn a => (a, g ()),
        sync = fn ab => ab,
        unstolen = NONE
      }

  fun parfor grain (i, j) f =
      let
         fun for (i, j) f =
             if i >= j then
                ()
             else (f i; for (i+1, j) f)
      in
        if j - i <= grain then
          for (i, j) f
        else
          let
            val mid = i + (j-i) div 2
          in
            par (fn _ => parfor grain (i, mid) f,
                 fn _ => parfor grain (mid, j) f)
          ; ()
          end
      end

  fun alloc n =
    let
      val a = ArrayExtra.Raw.alloc n
      val _ =
        if ArrayExtra.Raw.uninitIsNop a then ()
        else parfor 10000 (0, n) (fn i => ArrayExtra.Raw.unsafeUninit (a, i))
    in
      ArrayExtra.Raw.unsafeToArray a
    end

end

val x = Array.sub (ForkJoin0.alloc 1: int array, 0)
fun f n = if n = 0 then () else (MLton.Trace.noTuple x; ForkJoin0.par (fn _ => f (n-1), fn _ => ()); ())
val _ = f 1
