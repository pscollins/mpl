structure Scheduler =
struct

  fun arraySub (a, i) = Array.sub (a, i)
  fun arrayUpdate (a, i, x) = Array.update (a, i, x)
  fun vectorSub (v, i) = Vector.sub (v, i)

  val maxCCDepth = 1
  val P = 1
  fun myWorkerId ()  = MLton.Parallel.processorNumber ()

  fun die strfn = OS.Process.exit OS.Process.failure


  type gcstate = MLton.Pointer.t
  val gcstate = _prim "GC_state": unit -> gcstate;

  datatype TokenPolicy =
      TokenPolicyFair (* 0w0 *)

  val traceSchedSpawn = _import "GC_Trace_schedSpawn" private: gcstate -> unit; o gcstate
  val traceSchedJoin = _import "GC_Trace_schedJoin" private: gcstate -> unit; o gcstate
  val traceSchedJoinFast = _import "GC_Trace_schedJoinFast" private: gcstate -> unit; o gcstate

  structure Queue = DequeABP (*ArrayQueue*)
  structure Thread = MLton.Thread.Basic

  val nextPromotionTokenPolicy =
    _import "GC_HH_getNextPromotionTokenPolicy" runtime private: gcstate * Thread.t -> Word32.word;
  val nextPromotionTokenPolicy =
    (fn __inline_always__ thread => case nextPromotionTokenPolicy (gcstate (), thread) of
                  0w0 => TokenPolicyFair
                | w => die (fn _ => "Unknown token policy " ^ Word32.toString w))
  
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
  val primForkThreadAndSetData_youngest = _prim "spork_forkThreadAndSetData_youngest": Thread.t * 'a -> Thread.p;

  val findNextPromotableFrame =
    _import "GC_HH_findNextPromotableFrame" runtime private: gcstate * bool * Thread.t -> bool;
  val findNextPromotableFrame =
      (fn __inline_always__ ({youngestOptimization}, p) =>
          findNextPromotableFrame (gcstate (), youngestOptimization, p))
      : {youngestOptimization: bool} * Thread.t -> bool;

  fun assertAtomic msg x = ()

  val threadSwitchEndAtomic = Thread.switchTo

  structure HM = MLton.HM
  structure HH = MLton.Thread.HierarchicalHeap
  type hh_address = Word64.word
  type gctask_data = Thread.t * (hh_address ref)

  structure DE = MLton.Thread.Disentanglement

  local
    (** See MAX_FORK_DEPTH in runtime/gc/decheck.c *)
    val maxDisetanglementCheckDepth = DE.decheckMaxDepth ()
  in
  fun depthOkayForDECheck depth =
    case maxDisetanglementCheckDepth of
      (* in this case, there is no entanglement detection, so no problem *)
      NONE => true

      (* entanglement checks are active, and the max depth is m *)
    | SOME m => depth < m
  end


  fun faa (r, d) = MLton.Parallel.fetchAndAdd r d
  fun casRef r (old, new) =
    (MLton.Parallel.compareAndSwap r (old, new) = old)
  fun decrementHitsZero (x : int ref) : bool =
    faa (x, ~1) = 1

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
  fun dbgmsg m = ()

  fun dbgmsg' m = ()
  fun dbgmsg' _ = ()


  fun dbgmsg''' m = ()

  fun dbgmsg'' _ = ()

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

  val numSpawns = Array.array (P, 0)
  val numEagerSpawns = Array.array (P, 0)
  val numHeartbeats = Array.array (P, 0)
  val numSkippedHeartbeats = Array.array (P, 0)
  val numSteals = Array.array (P, 0)
  val numSlowJoins = Array.array (P, 0)
  val numFastJoins = Array.array (P, 0)

  fun incrementNumSpawns () =
    let
      val p = myWorkerId ()
      val c = arraySub (numSpawns, p)
    in
      arrayUpdate (numSpawns, p, c+1)
    end

  fun addEagerSpawns d =
    let
      val p = myWorkerId ()
      val c = arraySub (numEagerSpawns, p)
    in
      arrayUpdate (numEagerSpawns, p, c+d)
    end

  fun incrementNumHeartbeats () =
    let
      val p = myWorkerId ()
      val c = arraySub (numHeartbeats, p)
    in
      arrayUpdate (numHeartbeats, p, c+1)
    end

  fun incrementNumSkippedHeartbeats () =
    let
      val p = myWorkerId ()
      val c = arraySub (numSkippedHeartbeats, p)
    in
      arrayUpdate (numSkippedHeartbeats, p, c+1)
    end

  fun incrementNumSteals () =
    let
      val p = myWorkerId ()
      val c = arraySub (numSteals, p)
    in
      arrayUpdate (numSteals, p, c+1)
    end

  fun incrementNumSlowJoins () =
    let
      val p = myWorkerId ()
      val c = arraySub (numSlowJoins, p)
    in
      arrayUpdate (numSlowJoins, p, c+1)
      (* MLton.Parallel.arrayFetchAndAdd (numSlowJoins, p) 1 *)
    end

  fun incrementNumFastJoins () =
    let
      val p = myWorkerId ()
      val c = arraySub (numFastJoins, p)
    in
      (* MLton.Parallel.arrayFetchAndAdd (numFastJoins, p) 1 *)
      arrayUpdate (numFastJoins, p, c+1)
    end

  fun numSpawnsSoFar () =
    Array.foldl op+ 0 numSpawns

  fun numEagerSpawnsSoFar () =
    Array.foldl op+ 0 numEagerSpawns

  fun numHeartbeatsSoFar () =
    Array.foldl op+ 0 numHeartbeats

  fun numSkippedHeartbeatsSoFar () =
    Array.foldl op+ 0 numSkippedHeartbeats

  fun numStealsSoFar () =
    Array.foldl op+ 0 numSteals

  fun numSlowJoinsSoFar () =
    Array.foldl op+ 0 numSlowJoins

  fun numFastJoinsSoFar () =
    Array.foldl op+ 0 numFastJoins

  (** ========================================================================
    * TIMERS
    *)

  structure IdleTimer = CumulativePerProcTimer(val timerName = "idle")
  structure WorkTimer = CumulativePerProcTimer(val timerName = "work")

  (** ========================================================================
    * MAXIMUM FORK DEPTHS
    *)

  val maxForkDepths = Array.array (P, 0)

  fun maxForkDepthSoFar () =
    Array.foldl Int.max 0 maxForkDepths

  fun recordForkDepth d =
    let
      val p = myWorkerId ()
    in
      if arraySub (maxForkDepths, p) >= d then
        ()
      else
        ( (*print ("max increased: " ^ Int.toString d ^ "\n")*) ()
        ; arrayUpdate (maxForkDepths, p, d)
        )
    end

  (* ========================================================================
   * CHILD TASK PROTOTYPE THREAD
   *
   * this widget makes it possible to create new "user" threads by copying
   * the prototype thread, which immediately pulls a task out of the
   * current worker's task-box and then executes it.
   *)

  local
    val amOriginal = ref true
    val taskBoxes = Array.array (P, NONE)
    fun upd i x = HM.arrayUpdateNoBarrier (taskBoxes, i, x)
    fun sub i = HM.arraySubNoBarrier (taskBoxes, i)
  in
  val _ = Thread.copyCurrent ()
  val prototypeThread : Thread.p =
    if !amOriginal then
      (amOriginal := false; Thread.savedPre ())
    else
      case sub (myWorkerId ()) of
        NONE => die (fn _ => "scheduler bug: task box is empty")
      | SOME t =>
          ( upd (myWorkerId ()) NONE
          ; t () handle _ => ()
          ; die (fn _ => "scheduler bug: child task didn't exit properly")
          )
  fun setTaskBox p t =
    upd p (SOME t)
  end

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

  fun queueSize () =
    let
      val myId = myWorkerId ()
      val {queue, ...} = vectorSub (workerLocalData, myId)
    in
      Queue.size queue
    end

  fun push (x): unit =
    let
      val myId = myWorkerId ()
      val {queue, ...} = vectorSub (workerLocalData, myId)
    in
      Queue.pushBot queue x
    end

  fun clear () =
    let
      val myId = myWorkerId ()
      val {queue, ...} = vectorSub (workerLocalData, myId)
    in
       ()
    end

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
            val cont_arr1 = ref NONE
            val cont_arr2 = ref NONE
            val cont_arr3 = ref (SOME (fn _ => (gcTask, gcTaskData))) (* a hack, I hope it works. *)

            (** The above could trigger a local GC and invalidate the hh
              * identifier... :'(
              *)
            val _ = heapId := HH.getRoot thread
          in
            if not (HH.registerCont (cont_arr1, cont_arr2, cont_arr3, thread)) then
              NONE
            else
              let
                val (tidLeft, tidRight) = DE.decheckFork ()
                val _ = push gcTask
                val _ = HH.setDepth (thread, depth + 1)
                val _ = DE.decheckSetTid tidLeft
                val _ = HH.forceLeftHeap(myWorkerId(), thread)
              in
                SOME (GCJ {gcTaskData = gcTaskData, tidRight = tidRight})
              end
          end
      end


    (* runs in signal handler *)
    fun doSpawn {youngestOptimization: bool} (interruptedLeftThread: Thread.t) : unit =
      let
        val gcj = spawnGC interruptedLeftThread
        val _ = assertAtomic "spawn after spawnGC" 1

        val thread = Thread.current ()
        val depth = HH.getDepth thread

        val _ = dbgmsg'' (fn _ => "spawning at depth " ^ Int.toString depth)

        (* We use a ref here instead of using rightSideThread directly.
         * The rightSideThread is a Thread.p (it doesn't have a heap yet).
         * The thief will convert it into a Thread.t and give it a heap,
         * and then write it into this slot. *)
        val rightSideThreadSlot = ref (NONE: Thread.t option)
        val rightSideResult = ref (NONE: Universal.t Result.t option)
        val incounter = ref 2

        val tidParent = DE.decheckGetTid thread
        val (tidLeft, tidRight) = DE.decheckFork ()

        val _ = Heartbeat.consumeSpare Heartbeat.spawnCost

        val tokenPolicy = nextPromotionTokenPolicy interruptedLeftThread
        val giveTokens = case tokenPolicy of
                             TokenPolicyFair => Heartbeat.halfOfCurrent ()
        val _ = Heartbeat.consumeSpare giveTokens
        (* val spareBefore = currentSpareHeartbeatTokens () *)
        (* val spareHB = ref 0w0 *)
        val jp =
          J { leftSideThread = interruptedLeftThread
            , rightSideThread = rightSideThreadSlot
            , rightSideResult = rightSideResult
            , incounter = incounter
            , tidRight = tidRight
            , spareHeartbeatsGiven = giveTokens
            , tokenPolicy = tokenPolicy
            , gcj = gcj
            }

        (* this sets the join for both threads (left and right) *)
        val rightSideThread =
            primForkThreadAndSetData (interruptedLeftThread, jp)

        (* determine how many heartbeats given to rhs from difference vs before *)
        (* val _ = spareHB := spareBefore - currentSpareHeartbeatTokens () *)

        (* double check... hopefully correct, not off by one? *)
        val _ = push (NewThread (rightSideThread, tidParent, depth))
        val _ = HH.setDepth (thread, depth + 1)

        (* NOTE: off-by-one on purpose. Runtime depths start at 1. *)
        val _ = recordForkDepth depth

        val _ = incrementNumSpawns ()
        val _ = traceSchedSpawn ()

        val _ = DE.decheckSetTid tidLeft
        val _ = assertAtomic "spawn done" 1
      in
        ()
      end


    (* runs in signal handler *)
    fun maybeSpawn youngestOptimization (interruptedLeftThread: Thread.t) : bool =
        (doSpawn youngestOptimization interruptedLeftThread ; true)


    fun maybeSpawnFunc {allowCGC: bool} (g: unit -> 'a) : 'a joinpoint option = NONE

    (** Must be called in an atomic section. Implicit atomicEnd() *)
    fun syncEndAtomic
        (doClearSuspects: Thread.t * int -> unit)
        (J {rightSideThread, rightSideResult, incounter, tidRight, gcj, spareHeartbeatsGiven, tokenPolicy, ...} : 'a joinpoint)
        : 'a Result.t option
      = 
      let
        val _ = assertAtomic "syncEndAtomic begin" 1

        val thread = Thread.current ()
        val depth = HH.getDepth thread
        val newDepth = depth-1
        val tidLeft = DE.decheckGetTid thread

        val result =
          (* Might seem like a space leak here, because we don't clean up the
           * thread that was spawned and added to the deque. But this is okay:
           * the thread hasn't been stolen, so it hasn't yet been converted
           * into a full thread. (The discarded thread is located in the current
           * heap, not in some other heap, so it will be garbage-collected
           * appropriately.)
           *)
          if popDiscard () then
            let val _ = dbgmsg'' (fn _ => "popDiscard success at depth " ^ Int.toString depth)
                (* promote chunks into parent, update depth->newDepth, update
                 * decheck state by joining tidLeft and tidRight.
                 *)
                val _ = HH.joinIntoParentBeforeFastClone
                          {thread=thread, newDepth=newDepth, tidLeft=tidLeft, tidRight=tidRight}
                val _ = traceSchedJoinFast ()
                val _ = Thread.atomicEnd ()
                val _ = doClearSuspects (thread, newDepth)
                val _ = if newDepth <> 1 then () else HH.updateBytesPinnedEntangledWatermark ()
                val _ = Heartbeat.zero
                val _ = incrementNumFastJoins ()
            in
              NONE
            end
          else
            ( if decrementHitsZero incounter then
                ()
              else
                ( ()
                  (** Atomic 1 *)
                ; assertAtomic "syncEndAtomic before returnToSched" 1
                ; returnToSchedEndAtomic ()
                ; assertAtomic "syncEndAtomic after returnToSched" 1
                )

            ; case HM.refDerefNoBarrier rightSideThread of
                NONE => die (fn _ => "scheduler bug: join failed")
              | SOME rightSideThread =>
                  let
                    val tidRight = DE.decheckGetTid rightSideThread

                    (* merge the two threads, promote chunks into parent, 
                     * update depth->newDepth, update the decheck state
                     *)
                    val _ = HH.joinIntoParent
                      { thread = thread
                      , rightSideThread = rightSideThread
                      , newDepth = newDepth
                      , tidLeft = tidLeft
                      , tidRight = tidRight
                      }

                    val _ = incrementNumSlowJoins ()

                    val _ = traceSchedJoin ()

                    (* SAM_NOTE: TODO: we really ought to make this part of
                     * the HH.joinIntoParent call, above. Is that possible?
                     *)
                    val _ = setQueueDepth (myWorkerId ()) newDepth

                    val result = 
                      case HM.refDerefNoBarrier rightSideResult of
                        NONE => die (fn _ => "scheduler bug: join failed: missing result")
                      | SOME gr =>
                          ( ()
                          ; assertAtomic "syncEndAtomic after merge" 1
                          ; Thread.atomicEnd ()
                          ; gr
                          )
                  in
                    doClearSuspects (thread, newDepth);
                    if newDepth <> 1 then () else HH.updateBytesPinnedEntangledWatermark ();
                    SOME result
                  end
            )
        val _ = case gcj of
                    NONE => ()
                  | SOME gcj => ()
      in
        result
      end

    fun simpleParFork (f: unit -> unit, g: unit -> unit) : unit =
      case maybeSpawnFunc {allowCGC = false} g of
        NONE => (f (); g ())
      | SOME gj =>
          let
            val fr = Result.result f
            val _ = Thread.atomicBegin ()
            val gro = syncEndAtomic maybeParClearSuspectsAtDepth gj
          in
            Result.extractResult fr;
            case gro of
                NONE => g ()
              | SOME gr => Result.extractResult gr
          end

    and maybeParClearSuspectsAtDepth (t, d) = ()

  
    val sched_package_data = ref
      { syncEndAtomic = syncEndAtomic maybeParClearSuspectsAtDepth
      , maybeSpawn = maybeSpawn
      , setQueueDepth = setQueueDepth
      , returnToSchedEndAtomic = returnToSchedEndAtomic
      , tryConsumeSpareHeartbeats = Heartbeat.consumeSpare
      , addEagerSpawns = addEagerSpawns
      , assertAtomic = assertAtomic
      , error = (fn s => die (fn _ => s)) : string -> unit
      }

    fun sched_package () = !sched_package_data

    exception SchedulerError

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
             __inline_always__ body ())

        fun spwn' ((), J jp): unit =
          let
            val _ = #assertAtomic (sched_package ()) "spork rightside begin" 1
            val () = DE.decheckSetTid (#tidRight jp)

            val thread = Thread.current ()
            val depth = HH.getDepth thread
            val _ = dbgmsg'' (fn _ => "rightside begin at depth " ^ Int.toString depth)

            val _ = HH.forceLeftHeap(myWorkerId(), thread)
            val _ = Heartbeat.addSpare (#spareHeartbeatsGiven jp)
            val _ = #assertAtomic (sched_package ()) "spork rightSide before execute" 1
            val _ = Thread.atomicEnd()

            val spwnr = Result.result (inject o spwn)

            val _ = Thread.atomicBegin ()
            val depth' = HH.getDepth (Thread.current ())
            val _ =
              if depth = depth' then ()
              else #error (sched_package ()) ("scheduler bug: rightide depth mismatch: " ^ Int.toString depth ^ " vs " ^ Int.toString depth')
            val _ = dbgmsg'' (fn _ => "rightside done! at depth " ^ Int.toString depth')
            val _ = #assertAtomic (sched_package ()) "spork rightside begin synchronize" 1
          in
            #rightSideThread jp := SOME thread;
            #rightSideResult jp := SOME spwnr;

            if decrementHitsZero (#incounter jp) then
              ( ()
              ; dbgmsg'' (fn _ => "rightside synchronize: become left")
              ; #setQueueDepth (sched_package ()) (myWorkerId ()) depth
                (** Atomic 1 *)
              ; Thread.atomicBegin ()

                (** Atomic 2 *)

                (** (When sibling is resumed, it needs to be atomic 1.
                  * Switching threads is implicit atomicEnd(), so we need
                  * to be at atomic2
                  *)
              ; #assertAtomic (sched_package ()) "spork rightside switch-to-left" 2
              ; threadSwitchEndAtomic (#leftSideThread jp)
              )
            else
              ( dbgmsg'' (fn _ => "rightside synchronize: back to sched")
              ; #assertAtomic (sched_package ()) "spork rightside before returnToSched" 1
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
