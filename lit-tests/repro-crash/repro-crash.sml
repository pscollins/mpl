(* This file reproduces a missed flattening bug in the compiler (which causes
the assertion corresponding to `Trace.noTuple` to fail)

TODO(pscollins): Make this file self contained by inlining all of the relevant
library code *)

type task = Word32.word
val GCTask = Word32.fromInt 0
structure Queue =
struct
fun exceededCapacityError () = print "Full\n"


   val ABP_deque_push_bot =
      _import "ABP_deque_push_bot2" private: task -> bool;

   val ABP_deque_try_pop_bot =
      _import "ABP_deque_try_pop_bot2" private:
         task -> task;

   fun pushBot (x: task): unit =
       if ABP_deque_push_bot (x) then
          ()
       else
          exceededCapacityError ()

   fun popBot (): task option = SOME (ABP_deque_try_pop_bot (GCTask))
end

structure Scheduler =
struct
   exception Die

   type gcstate = MLton.Pointer.t

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
         _import "GC_HH_joinIntoParentBeforeFastClone2" private:
         Word64.word -> unit;
      fun joinIntoParentBeforeFastClone {tidRight} =
         joinIntoParentBeforeFastClone' (tidRight)
   end

   structure DE =
   struct
      val decheckFork' = _import "GC_HH_decheckFork2" private:
         Word64.word ref -> unit;
      fun decheckFork () =
         let
            val kConst = 0w0: Word64.word
            val left = ref (kConst)
            val left = ref (kConst)
         in
            decheckFork' (left);
            (!left)
         end
   end

   datatype 'a joinpoint = J of
      {
         leftSideThread: Thread.t,
         rightSideThread: Thread.t option ref,
         tidRight: Word64.word
      }

   fun push (x): unit = Queue.pushBot x

   fun pop (): task option = Queue.popBot ()

   fun popDiscard () =
      case pop () of
         NONE => false
       | SOME _ => true

   fun doSpawn () : unit =
      let
         val _ = push GCTask
         val thread = Thread.current ()
         val rightSideThreadSlot = ref (NONE: Thread.t option)
         val tidRight = DE.decheckFork ()
         val jp = J
            {
               leftSideThread = thread,
               rightSideThread = rightSideThreadSlot,
               tidRight = tidRight
            }
         val _ = primForkThreadAndSetData (thread, jp)
      in
         ()
      end

   fun syncEndAtomic (tidRight) : unit =
      (
         if popDiscard () then
            HH.joinIntoParentBeforeFastClone
               {
                  tidRight=tidRight
               }
         else
            ()
      )

   fun __inline_always__ tryPromoteNow (): unit = doSpawn ()

   fun __inline_always__ sporkBase (body: unit -> 'a): 'c =
      let
         fun body' (): 'a = (tryPromoteNow (); body ())
         fun spwn' ((), J {rightSideThread, ...}): unit = rightSideThread := NONE
         fun seq' (bodyr: 'a): 'c = raise Die
         fun sync' (bodyr: 'a, J {tidRight, ...}: int joinpoint): 'c =
            (syncEndAtomic tidRight; raise Die)
         fun exnseq' (e: exn): 'c = raise e
         fun exnsync' (e: exn, J {tidRight, ...}: int joinpoint): 'c =
            (syncEndAtomic tidRight; raise Die)
      in
         primSporkFair (body', spwn', seq', sync', exnseq', exnsync')
      end

   fun __inline_always__ spork body = sporkBase body
end

structure ForkJoin0 =
struct
   val spork = Scheduler.spork

   fun par f = spork f

   fun parfor (i, j) f =
      if i = j then
         ()
      else
         (par (fn _ => parfor (i, 0) f))

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
      (MLton.Trace.noTuple x; ForkJoin0.par (fn _ => f (n-1)); ())

val _ = f 1
