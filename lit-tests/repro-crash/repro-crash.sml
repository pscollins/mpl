(* This file reproduces a missed flattening bug in the compiler (which causes
the assertion corresponding to `Trace.noTuple` to fail)

TODO(pscollins): Make this file self contained by inlining all of the relevant
library code *)

(* Minimal print implementation to reproduce the bug

IMPORTANT: When minimizing this program for debugging, DO NOT replace this
structure with a call to the built-in `print` function -- the built-in function
is much more complicated (from the compiler perspective) than this one; doing
this substitution would hurt our progress towards the goal.
 *)
structure MyTextIO = struct
datatype writer = WR of {
      writeVec: {buf: string, i: int, sz: int option} -> int
   }

   val chunkSize = 1024

   datatype buf = Buf of {array: char array, size: int ref}
   datatype buffer_mode = LINE_BUF
   datatype state = Closed

   datatype outstream = Out of {
      writer: writer,
      buf: buf option,
      mode: buffer_mode,
      state: state ref
   }

   fun mkOutstream (writer) =
      let
         val buf = SOME (Buf {array = Array.array (chunkSize, #"\000"),
                              size = ref 0})
      in
         Out {writer = writer, buf = buf, mode = LINE_BUF, state = ref Closed}
      end

   fun flushOut (Out {writer as WR {writeVec, ...}, buf, state, ...}) =
      case (!state, buf) of
         (_, SOME (Buf {array, ...})) =>
         let
            val v = Array.vector array
            val _ = writeVec {buf = v, i = 0, sz = SOME (0)}
         in
            ()
         end
       | _ => ()
   fun output (os as Out {writer as WR {writeVec, ...}, buf, mode, state, ...}, v) =
       if !state = Closed then raise Fail "Closed stream"
       else case buf of
                NONE => (ignore (writeVec {buf = v, i = 0, sz = NONE}))
              | SOME (Buf {array, ...}) =>
                let
                   val len = String.size v
                   val current = 1
                in
                   if current + len < Array.length array then
                      (Array.copyVec {src = v, dst = array, di = current};
                       if mode = LINE_BUF andalso CharVector.exists (fn c => c = #"\n") v 
                       then flushOut os else ())
                   else
                      (flushOut os;
                       ignore (writeVec {buf = v, i = 0, sz = NONE}))
                end
   fun output' (os, v) = output (!os, v)
   val writeChar8Vec = _import "Posix_IO_writeChar8Vec" private : int * string * int * word -> int;

   val mkWriter = fn fd => WR {
      writeVec = fn {buf, i, sz} =>
         let
            val len = Word.fromInt (String.size buf - i)
         in
            writeChar8Vec (fd, buf, i, len)
         end
   }

   val stdOut = ref (mkOutstream (mkWriter 1))

   fun print s = output' (stdOut, s)
end

(* --- Layer 5: Top-level --- *)
val my_print = MyTextIO.print


val GCTask = Word32.fromInt 0
structure Queue =
struct
  fun exceededCapacityError () = my_print "Full\n"


   val ABP_deque_push_bot =
      _import "ABP_deque_push_bot2" private: Word32.word -> bool;

   fun pushBot (x: Word32.word): unit =
       if ABP_deque_push_bot (x) then
          ()
       else
          exceededCapacityError ()
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

   val joinIntoParentBeforeFastClone' =
      _import "GC_HH_joinIntoParentBeforeFastClone2" private:
      Word64.word -> unit;

   val decheckFork' = _import "GC_HH_decheckFork2" private:
      Word64.word ref -> unit;
   fun decheckFork () =
      let
         val kConst = 0w0: Word64.word
         val left = ref (kConst)
      in
         decheckFork' (left);
         (!left)
      end

   datatype 'a joinpoint = J of
      {
         leftSideThread: Thread.t,
         rightSideThread: Thread.t option ref,
         tidRight: Word64.word
      }

   fun push (x): unit = Queue.pushBot x


   fun doSpawn () : unit =
      let
         val _ = push GCTask
         val thread = Thread.current ()
         val rightSideThreadSlot = ref (NONE: Thread.t option)
         val tidRight = decheckFork ()
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
            joinIntoParentBeforeFastClone'
                tidRight

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

val x = Array.sub (ForkJoin0.alloc 1: Word16.word array, 0)

fun f n =
   if n = 0 then
      ()
   else
      (MLton.Trace.noTuple x; ForkJoin0.par (fn _ => f (n-1)); ())

val _ = f 1
