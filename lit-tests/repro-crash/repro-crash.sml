structure Queue =
struct
   val capacity = 1

   fun die strfn = (print (strfn () ^ "\n"))

   fun exceededCapacityError () = die (fn _ => "Full")

   type gcstate = MLton.Pointer.t

   val ABP_deque_push_bot =
      _import "ABP_deque_push_bot" runtime private:
         gcstate * Word32.word ref * Word32.word ref * 'a option array * 'a option -> bool;

   val ABP_deque_try_pop_bot =
      _import "ABP_deque_try_pop_bot" runtime private:
         gcstate * Word32.word ref * Word32.word ref * 'a option array * 'a option -> 'a option;

   type 'a t = {}

   fun new () = {}

   val kNull = MLton.Pointer.null

   fun pushBot (q as {}) x =
      let
         val kConst = ref (0w32: Word32.word)
         val data' = Array.array (1, NONE)
      in
         if ABP_deque_push_bot (kNull, kConst, kConst, data', SOME x) then
            ()
         else
            exceededCapacityError ()
      end

   fun popBot (q as {}) =
      let
         val kConst = ref (0w32: Word32.word)
         val data' = Array.array (1, NONE)
      in
         ABP_deque_try_pop_bot (kNull, kConst, kConst, data', NONE)
      end
end

structure Scheduler =
struct
   exception Die

   type gcstate = MLton.Pointer.t

   val gcstate = _prim "GC_state": unit -> gcstate;

   structure Thread = MLton.Thread.Basic

   val primSporkFair' =
      _prim "spork_fair" :
         ('aa -> 'ar) * 'aa * ('ba * 'd -> 'br) * 'ba * ('ar -> 'c) * ('ar * 'd -> 'c) * (exn -> 'c) * (exn * 'd -> 'c) -> 'c;

   fun __inline_always__ primSporkFair (body, spwn, seq, sync, exnseq, exnsync) =
      __inline_always__ primSporkFair' (body, (), spwn, (), seq, sync, exnseq, exnsync)

   val primForkThreadAndSetData = _prim "spork_forkThreadAndSetData": Thread.t * 'a -> Thread.p;

   structure HH = MLton.Thread.HierarchicalHeap
   structure DE = MLton.Thread.Disentanglement

   datatype 'a joinpoint = J of
      {
         leftSideThread: Thread.t,
         rightSideThread: Thread.t option ref,
         tidRight: Word64.word
      }

   datatype task = GCTask

   fun push (x): unit = Queue.pushBot (Queue.new()) x

   fun pop (): task option = Queue.popBot (Queue.new())

   fun popDiscard () =
      case pop () of
         NONE => false
       | SOME _ => true

   fun doSpawn (interruptedLeftThread: Thread.t) : unit =
      let
         val _ = push GCTask
         val thread = Thread.current ()
         val _ = HH.getDepth thread
         val rightSideThreadSlot = ref (NONE: Thread.t option)
         val _ = DE.decheckGetTid thread
         val (_, tidRight) = DE.decheckFork ()
         val jp = J
            {
               leftSideThread = interruptedLeftThread,
               rightSideThread = rightSideThreadSlot,
               tidRight = tidRight
            }
         val _ = primForkThreadAndSetData (interruptedLeftThread, jp)
      in
         ()
      end

   fun maybeSpawn (t: Thread.t) = (doSpawn t ; true)

   fun syncEndAtomic _ (J {tidRight, ...} : 'a joinpoint) : unit =
      (
         if popDiscard () then
            HH.joinIntoParentBeforeFastClone
               {
                  thread=Thread.current (),
                  newDepth=1,
                  tidLeft=Word64.fromInt 0,
                  tidRight=tidRight
               }
         else
            ()
      )

   val sched_package =
      {
         syncEndAtomic = syncEndAtomic (fn _ => ()),
         maybeSpawn = maybeSpawn,
         returnToSchedEndAtomic = ()
      }

   fun __inline_always__ tryPromoteNow (): unit =
      (#maybeSpawn (sched_package) (Thread.current ()); ())

   fun __inline_always__ sporkBase (body: unit -> 'a): 'c =
      let
         fun body' (): 'a = (tryPromoteNow (); body ())
         fun spwn' ((), J jp): unit = #rightSideThread jp := SOME (Thread.current ())
         fun seq' (bodyr: 'a): 'c = raise Die
         fun sync' (bodyr: 'a, jp: int joinpoint): 'c =
            (#syncEndAtomic (sched_package) jp; raise Die)
         fun exnseq' (e: exn): 'c = raise e
         fun exnsync' (e: exn, jp: int joinpoint): 'c =
            (#syncEndAtomic (sched_package) jp; raise Die)
      in
         primSporkFair (body', spwn', seq', sync', exnseq', exnsync')
      end

   fun __inline_always__ spork {body, spwn, seq, sync, unstolen} = sporkBase body
end

structure ForkJoin0 =
struct
   val spork = Scheduler.spork

   fun par (f, g) =
      spork { body = f, spwn = g, seq = fn a => (a, g ()), sync = fn ab => ab, unstolen = NONE }

   fun parfor (i, j) f =
      if i = j then
         ()
      else
         (par (fn _ => parfor (i, 0) f, fn _ => parfor (0, j) f); ())

   fun alloc n =
      let
         val a = ArrayExtra.Raw.alloc n
         val _ =
            if ArrayExtra.Raw.uninitIsNop a then
               ()
            else
               parfor (0, n) (fn i => ArrayExtra.Raw.unsafeUninit (a, i))
      in
         ArrayExtra.Raw.unsafeToArray a
      end
end

val x = Array.sub (ForkJoin0.alloc 1: int array, 0)

fun f n =
   if n = 0 then
      ()
   else
      (MLton.Trace.noTuple x; ForkJoin0.par (fn _ => f (n-1), fn _ => ()); ())

val _ = f 1
