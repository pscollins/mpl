(* This file reproduces a missed flattening bug in the compiler (which causes
the assertion corresponding to `Trace.noTuple` to fail)

TODO(pscollins): Make this file self contained by inlining all of the relevant
library code *)

structure Queue =
struct
   val capacity = 1

   fun exceededCapacityError () = print "Full\n"

   type gcstate = MLton.Pointer.t

   val ABP_deque_push_bot =
      _import "ABP_deque_push_bot" runtime private:
         gcstate * Word32.word ref * Word32.word ref * 'a option array * 'a option -> bool;

   val ABP_deque_try_pop_bot =
      _import "ABP_deque_try_pop_bot" runtime private:
         gcstate * Word32.word ref * Word32.word ref * 'a option array * 'a option -> 'a option;

   val kNull = MLton.Pointer.null

   fun pushBot x =
      let
         val kConst = ref (0w32: Word32.word)
         val data' = Array.array (1, NONE)
      in
         if ABP_deque_push_bot (kNull, kConst, kConst, data', SOME x) then
            ()
         else
            exceededCapacityError ()
      end

   fun popBot () =
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
      ('aa -> 'ar)
      * 'aa
      * ('ba * 'd -> 'br)
      * 'ba * ('ar -> 'c)
      * ('ar * 'd -> 'c)
      * (exn -> 'c)
      * (exn * 'd -> 'c) -> 'c;

   fun __inline_always__ primSporkFair (body, spwn, seq, sync, exnseq, exnsync) =
      __inline_always__ primSporkFair' (body, (), spwn, (), seq, sync, exnseq, exnsync)

   val primForkThreadAndSetData = _prim "spork_forkThreadAndSetData": Thread.t * 'a -> Thread.p;

   structure HH =
   struct
      val joinIntoParentBeforeFastClone' =
         _import "GC_HH_joinIntoParentBeforeFastClone" runtime private:
         gcstate * Thread.t * Word32.word * Word64.word * Word64.word -> unit;
      fun joinIntoParentBeforeFastClone {thread, newDepth, tidLeft, tidRight} =
         joinIntoParentBeforeFastClone' (gcstate (), thread, Word32.fromInt newDepth, tidLeft, tidRight)
   end

   structure DE =
   struct
      val decheckFork' = _import "GC_HH_decheckFork" runtime private:
         gcstate * Word64.word ref * Word64.word ref -> unit;
      fun decheckFork () =
         let
            val kConst = 0w0: Word64.word
            val left = ref (kConst)
         in
            decheckFork' (gcstate (), left, left);
            (!left)
         end
   end

   datatype 'a joinpoint = J of
      {
         leftSideThread: Thread.t,
         rightSideThread: Thread.t option ref,
         tidRight: Word64.word
      }

   datatype task = GCTask

   fun push (x): unit = Queue.pushBot x

   fun pop (): task option = Queue.popBot ()

   fun popDiscard () =
      case pop () of
         NONE => false
       | SOME _ => true

   fun doSpawn (interruptedLeftThread: Thread.t) : unit =
      let
         val _ = push GCTask
         val thread = Thread.current ()
         val rightSideThreadSlot = ref (NONE: Thread.t option)
         val tidRight = DE.decheckFork ()
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

   fun syncEndAtomic (J {tidRight, ...} : 'a joinpoint) : unit =
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

   fun __inline_always__ tryPromoteNow (): unit =
      (doSpawn (Thread.current ()); ())

   fun __inline_always__ sporkBase (body: unit -> 'a): 'c =
      let
         fun body' (): 'a = (tryPromoteNow (); body ())
         fun spwn' ((), J jp): unit = #rightSideThread jp := SOME (Thread.current ())
         fun seq' (bodyr: 'a): 'c = raise Die
         fun sync' (bodyr: 'a, jp: int joinpoint): 'c =
            (syncEndAtomic jp; raise Die)
         fun exnseq' (e: exn): 'c = raise e
         fun exnsync' (e: exn, jp: int joinpoint): 'c =
            (syncEndAtomic jp; raise Die)
      in
         primSporkFair (body', spwn', seq', sync', exnseq', exnsync')
      end

   fun __inline_always__ spork body = sporkBase body
end

structure ForkJoin0 =
struct
   val spork = Scheduler.spork

   fun par (f, g) = spork f

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
