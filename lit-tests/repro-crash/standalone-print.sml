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
val print = MyTextIO.print

val _ = (print "Expanded layered print implementation starting...\n";
         print "This uses LINE_BUF, and calls _import 'Posix_IO_writeChar8Vec' directly.\n";
         print "Finalizing output.\n")
