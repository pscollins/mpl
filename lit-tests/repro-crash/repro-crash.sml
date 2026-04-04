(* This file reproduces a missed flattening bug in the compiler (which causes
the assertion corresponding to `Trace.noTuple` to fail)

TODO(pscollins): Make this file self contained by inlining all of the relevant
library code *)

(* --- Layer 0: Direct FFI Imports (Mirroring PrimitiveFFI) --- *)
structure PrimitiveFFI = struct
   (* C_Fd_t = int, String8_t = string, C_Int_t = int, C_Size_t = word, C_SSize_t = int *)
   val writeChar8Vec = _import "Posix_IO_writeChar8Vec" private : int * string * int * word -> int;
end

(* --- Layer 1: PrimIO --- *)
signature PRIM_IO = sig
   type vector = string
   datatype writer = WR of {
      writeVec: {buf: vector, i: int, sz: int option} -> int,
      name: string,
      chunkSize: int
   }
   type writer_type = writer
end

structure TextPrimIO : PRIM_IO = struct
   type vector = string
   datatype writer = WR of {
      writeVec: {buf: vector, i: int, sz: int option} -> int,
      name: string,
      chunkSize: int
   }
   type writer_type = writer
end

(* --- Layer 2: StreamIO (Buffering and state management) --- *)
signature STREAM_IO = sig
   type vector
   type writer
   type outstream
   datatype buffer_mode = NO_BUF | LINE_BUF | BLOCK_BUF
   val mkOutstream: writer * buffer_mode -> outstream
   val output: outstream * vector -> unit
   val flushOut: outstream -> unit
end

functor StreamIOExtra (P: PRIM_IO) : STREAM_IO 
  where type vector = P.vector 
  where type writer = P.writer_type = struct
   type vector = P.vector
   type writer = P.writer_type
   datatype buf = Buf of {array: char array, size: int ref}
   datatype buffer_mode = NO_BUF | LINE_BUF | BLOCK_BUF
   datatype state = Active | Closed

   datatype outstream = Out of {
      writer: P.writer_type,
      buf: buf option,
      mode: buffer_mode,
      state: state ref
   }

   fun mkOutstream (writer, mode) =
      let
         val P.WR {chunkSize, ...} = writer
         val buf = case mode of
                      NO_BUF => NONE
                    | _ => SOME (Buf {array = Array.array (chunkSize, #"\000"),
                                     size = ref 0})
      in
         Out {writer = writer, buf = buf, mode = mode, state = ref Active}
      end

   fun flushOut (Out {writer as P.WR {writeVec, ...}, buf, state, ...}) =
      case (!state, buf) of
         (Active, SOME (Buf {array, size})) =>
            if !size > 0 then
               let
                  val v = Array.vector array
                  val _ = writeVec {buf = v, i = 0, sz = SOME (!size)}
               in
                  size := 0
               end
            else ()
       | _ => ()

   fun output (os as Out {writer as P.WR {writeVec, ...}, buf, mode, state, ...}, v) =
      if !state = Closed then raise Fail "Closed stream"
      else case buf of
         NONE => (ignore (writeVec {buf = v, i = 0, sz = NONE}))
       | SOME (Buf {array, size}) =>
            let
               val len = String.size v
               val current = !size
            in
               if current + len < Array.length array then
                  (Array.copyVec {src = v, dst = array, di = current};
                   size := current + len;
                   if mode = LINE_BUF andalso CharVector.exists (fn c => c = #"\n") v 
                   then flushOut os else ())
               else
                  (flushOut os;
                   ignore (writeVec {buf = v, i = 0, sz = NONE}))
            end
end

(* --- Layer 4: TextIO Implementation --- *)
structure MyTextIO = struct
   structure SIO = StreamIOExtra(TextPrimIO)
   
   type outstream = SIO.outstream ref
   fun output (os, v) = SIO.output (!os, v)
   fun flushOut os = SIO.flushOut (!os)

   val mkWriter = fn fd => TextPrimIO.WR {
      name = "<stdout>",
      chunkSize = 4096,
      writeVec = fn {buf, i, sz} =>
         let
            val len = case sz of NONE => Word.fromInt (String.size buf - i)
                               | SOME n => Word.fromInt n
         in
            PrimitiveFFI.writeChar8Vec (fd, buf, i, len)
         end
   }

   val stdOut = ref (SIO.mkOutstream (mkWriter 1, SIO.LINE_BUF))

   fun print s = (output (stdOut, s); flushOut stdOut)
end

(* --- Layer 5: Top-level --- *)
val my_print = MyTextIO.print


val GCTask = Word32.fromInt 0
structure Queue =
struct
fun exceededCapacityError () = my_print "Full\n"


   val ABP_deque_push_bot =
      _import "ABP_deque_push_bot2" private: Word32.word -> bool;

   val ABP_deque_try_pop_bot =
      _import "ABP_deque_try_pop_bot2" private:
         Word32.word -> Word32.word;

   fun pushBot (x: Word32.word): unit =
       if ABP_deque_push_bot (x) then
          ()
       else
          exceededCapacityError ()

   fun popBot (): Word32.word option = SOME (ABP_deque_try_pop_bot (GCTask))
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
      fun joinIntoParentBeforeFastClone tidRight =
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

   fun pop (): Word32.word option = Queue.popBot ()


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
            HH.joinIntoParentBeforeFastClone
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
