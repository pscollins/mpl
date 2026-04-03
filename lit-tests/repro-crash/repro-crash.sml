(* non-resizing concurrent deque for work-stealing.
 * hard-coded capacity, see below. *)
structure Queue :
sig
  type 'a t
  exception Full

  val capacity : int

  val new : unit -> 'a t
  val clear : 'a t -> unit

  (* register this deque with the specified worker id *)
  val register : 'a t -> int -> unit

  (* set the minimum depth of this deque, i.e. the fork depth of the
   * MLton thread that is currently using this deque. This is used to
   * interface with the runtime, to coordinate local garbage collections. *)
  val setDepth : 'a t -> int -> unit

  (* raises Full if at capacity *)
  val pushBot : 'a t -> 'a -> unit

  (* returns NONE if deque is empty *)
  val popBot : 'a t -> 'a option
  val tryPopTop : 'a t -> 'a option

  val size : 'a t -> int
  val numResets : 'a t -> int
end =
struct

  (* capacity is configurable, but should be small. We need to be able to
   * tag indices and pack them into 64-bit words.
   * We also subtract 1 so that we can use index ranges of the form
   * [lo, hi) where 0 <= lo,hi < capacity
   *)
  val capacityPow = 6 (* DO NOT CHANGE THIS WITHOUT ALSO CHANGING runtime/gc/... *)
  val capacity = Word.toInt (Word.<< (0w1, Word.fromInt capacityPow)) - 1

  fun myWorkerId () =
    MLton.Parallel.processorNumber ()

  fun die strfn =
    ( print (strfn () ^ "\n")
    ; OS.Process.exit OS.Process.failure
    )

  val capacityStr = Int.toString capacity
  fun exceededCapacityError () =
    die (fn _ => "Scheduler error: exceeded max fork depth (" ^ capacityStr ^ ")")

  (* we tag indices and pack into a single 64-bit word, to
   * compare-and-swap as a unit. *)
  structure TagIdx :
  sig
    type t = Word64.word
    val maxTag : Word64.word
    val maxIdx : int
    val pack : {tag : Word64.word, idx : int} -> t
    val unpack : t -> {tag : Word64.word, idx : int}
  end =
  struct
    type t = Word64.word

    (* NOTE: this actually computes 1 + floor(log_2(n)), i.e. the number of
     * bits required to represent n in binary *)
    fun log2 n =
        let fun loop n acc =
                if n = 0w0 then
                  Word64.toInt acc
                else
                  loop (Word64.>> (n, 0w1)) (acc + 0w1)
        in
          loop (Word64.fromInt n) 0w0
        end

    val maxIdx = capacity
    val idxBits = Word.fromInt (log2 maxIdx)
    val idxMask = Word64.fromInt maxIdx

    val tagBits = 0w64 - idxBits
    val maxTag = Word64.- (Word64.<< (0w1, tagBits), 0w1)

    fun pack {tag, idx} =
      Word64.orb (Word64.<< (tag, idxBits), Word64.fromInt idx)

    fun unpack ti =
      let
        val idx = Word64.toInt (Word64.andb (ti, idxMask))
        val tag = Word64.>> (ti, idxBits)
      in
        {tag=tag, idx=idx}
      end
  end


  type gcstate = MLton.Pointer.t
  val gcstate = _prim "GC_state": unit -> gcstate;
  val ABP_deque_push_bot = _import "ABP_deque_push_bot" runtime private: gcstate * TagIdx.t ref * Word32.word ref * 'a option array * 'a option -> bool;
  val ABP_deque_try_pop_bot = _import "ABP_deque_try_pop_bot" runtime private: gcstate * TagIdx.t ref * Word32.word ref * 'a option array * 'a option -> 'a option;
  val ABP_deque_try_pop_top = _import "ABP_deque_try_pop_top" runtime private: gcstate * TagIdx.t ref * Word32.word ref * 'a option array * 'a option -> 'a option;
  val ABP_deque_set_depth = _import "ABP_deque_set_depth" runtime private: gcstate * TagIdx.t ref * Word32.word ref * 'a option array * Word32.word -> unit;


  type 'a t = {data : 'a option array,
               top : TagIdx.t ref,
               bot : Word32.word ref}

  exception Full

  fun for (i, j) f = if i = j then () else (f i; for (i+1, j) f)
  fun arrayUpdate (a, i, x) = MLton.HM.arrayUpdateNoBarrier (a, i, x)
  fun cas r (x, y) = MLton.Parallel.compareAndSwap r (x, y)

  fun cas32 b (x, y) = cas b (Word32.fromInt x, Word32.fromInt y)

  fun new () =
    {data = Array.array (capacity, NONE),
     top = ref (TagIdx.pack {tag=0w0, idx=0}),
     bot = ref (0w0 : Word32.word)}

  fun register ({top, bot, data, ...} : 'a t) p =
    ( MLton.HM.registerQueue (Word32.fromInt p, data)
    ; MLton.HM.registerQueueTop (Word32.fromInt p, top)
    ; MLton.HM.registerQueueBot (Word32.fromInt p, bot)
    )

  fun setDepth (q as {top, bot, data}) d =
    ABP_deque_set_depth (gcstate (), top, bot, data, Word32.fromInt d)

  fun clear ({data, ...} : 'a t) =
    for (0, Array.length data) (fn i => arrayUpdate (data, i, NONE))

  fun pushBot (q as {data, top, bot}) x =
    if ABP_deque_push_bot (gcstate (), top, bot, data, SOME x) then ()
    else exceededCapacityError ()

  fun tryPopTop (q as {data, top, bot}) =
    ABP_deque_try_pop_top (gcstate (), top, bot, data, NONE)

  fun popBot (q as {data, top, bot}) =
    ABP_deque_try_pop_bot (gcstate (), top, bot, data, NONE)

  fun size ({top, bot, ...} : 'a t) =
    let
      val thisBot = Word32.toInt (!bot)
      val {idx, ...} = TagIdx.unpack (!top)
    in
      thisBot - idx
    end

  fun numResets ({top, ...} : 'a t) =
    let
      val {tag, ...} = TagIdx.unpack (!top)
    in
      Word64.toInt tag
    end

end

structure Scheduler =
struct

  fun arraySub (a, i) = Array.sub (a, i)
  fun arrayUpdate (a, i, x) = Array.update (a, i, x)
  fun vectorSub (v, i) = Vector.sub (v, i)

  val maxCCDepth = 1
  val P = 1
  fun myWorkerId ()  = MLton.Parallel.processorNumber ()

  exception Die
  fun die strfn = raise Die
  fun die' () = raise Die

  type gcstate = MLton.Pointer.t
  val gcstate = _prim "GC_state": unit -> gcstate;

  datatype TokenPolicy =
      TokenPolicyFair (* 0w0 *)

  val traceSchedSpawn = _import "GC_Trace_schedSpawn" private: gcstate -> unit; o gcstate
  val traceSchedJoin = _import "GC_Trace_schedJoin" private: gcstate -> unit; o gcstate
  val traceSchedJoinFast = _import "GC_Trace_schedJoinFast" private: gcstate -> unit; o gcstate

  (* structure Queue = DequeABP (*ArrayQueue*) *)
  structure Thread = MLton.Thread.Basic

  (* structure Queue = struct *)
  (* type 'a t = 'a option ref *)

  (* fun new () =  *)
  (*    ref (NONE) *)

  (* fun pushBot (q: 'a t) (x: 'a) =  *)
  (*     q := (SOME x) *)

  (* fun popBot (q: 'a t) =  *)
  (*     !q *)
  (* end *)

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
      , tidRight: Word64.word
      }


  fun assertTokenInvariants thread msg = ()
  (* ========================================================================
   * TASKS
   *)

  (* In the case of NormalTask and NewThread, the Word64 is the decheck id that
   * we should use for the chunks allocated for these tasks.
   *)
  datatype task = GCTask 

  (* ========================================================================
   * STATS
   *)


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
    }

  fun wldInit (): worker_local_data =
    { queue = Queue.new ()
    , schedThread = ref NONE
    }

  val workerLocalData = ref (wldInit ())

  fun setGCTask p data = ()

  fun getGCTask p = NONE

  fun push (x): unit =
    let
      val myId = myWorkerId ()
      val {queue, ...} = !workerLocalData
    in
      Queue.pushBot queue x
    end

  fun clear () = ()

  fun pop (): task option =
    let
      val myId = myWorkerId ()
      val {queue, ...} = !workerLocalData
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

    (* runs in signal handler *)
    fun doSpawn (interruptedLeftThread: Thread.t) : unit =
      let
        val gcj = push GCTask

        val thread = Thread.current ()
        val depth = HH.getDepth thread

        (* We use a ref here instead of using rightSideThread directly.
         * The rightSideThread is a Thread.p (it doesn't have a heap yet).
         * The thief will convert it into a Thread.t and give it a heap,
         * and then write it into this slot. *)
        val rightSideThreadSlot = ref (NONE: Thread.t option)

        val tidParent = DE.decheckGetTid thread
        val (tidLeft, tidRight) = DE.decheckFork ()

        val jp =
          J { leftSideThread = interruptedLeftThread
            , rightSideThread = rightSideThreadSlot
            , tidRight = tidRight
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
        (J {rightSideThread, tidRight, ...} : 'a joinpoint)
        : 'a Result.t option
      = 
      let
        val thread = Thread.current ()
        val dummyTid = Word64.fromInt 0

        val result =
            if popDiscard () then
               let
                  val _ = HH.joinIntoParentBeforeFastClone
                              {thread=thread, newDepth=1,
                               tidLeft=dummyTid, tidRight=tidRight}
               in
                  NONE
               end
            else NONE
      in
        NONE
      end


    and maybeParClearSuspectsAtDepth (t, d) = ()

    val sched_package = 
        { syncEndAtomic = syncEndAtomic maybeParClearSuspectsAtDepth
        , maybeSpawn = maybeSpawn
        , returnToSchedEndAtomic = returnToSchedEndAtomic
        , assertAtomic = assertAtomic
      }

    (* ===================================================================
     * spork definition
     *)

    fun __inline_always__ tryPromoteNow () =
        (#maybeSpawn (sched_package) {youngestOptimization=true} (Thread.current ());
          ())

    type ('a, 'c) sporkT =
           (unit -> 'a)
         * (unit * Universal.t joinpoint -> unit)
         * ('a -> 'c)
         * ('a * Universal.t joinpoint -> 'c)
         * (exn -> 'c)
         * (exn * Universal.t joinpoint -> 'c)
         -> 'c

    fun __inline_always__ sporkBase (body: unit -> 'a): 'c =
        let
           fun dummySpwn(): 'b = raise Die
           fun dummySeq (x: 'a): 'c = raise Die
           val spwn = dummySpwn
           val seq = dummySeq
           fun dummySync (x: 'a, y: 'b): 'c = raise Die
           val sync = dummySync
           val unstolen = dummySeq
           val primSpork = primSporkFair
           fun dummyBody (): 'a = raise Die
         val (inject, project) = Universal.embed ()

        fun __inline_always__ body' (): 'a =
            ((if not (true) then () else tryPromoteNow ());
             body ())

        fun spwn' ((), J jp): unit =
          let
            val _ = #assertAtomic (sched_package) "spork rightside begin" 1

            val thread = Thread.current ()
            val spwnr = Result.result (inject o spwn)
          in
            #rightSideThread jp := SOME thread
          end

        fun __inline_always__ seq' (bodyr: 'a): 'c =
            __inline_always__ seq bodyr

        fun __inline_always__ sync' (bodyr: 'a, jp: Universal.t joinpoint): 'c =
          let
            val spwnrOpt = #syncEndAtomic (sched_package) jp
          in
             raise Die
          end

        fun __inline_always__ exnseq' (e: exn): 'c = raise e

        fun __inline_always__ exnsync' (e: exn, jp: Universal.t joinpoint): 'c =
            let val _ = #syncEndAtomic (sched_package) jp
            in
              raise Die
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
          sporkBase body
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
