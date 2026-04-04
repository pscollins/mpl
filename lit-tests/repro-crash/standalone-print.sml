(* 1. Primitive Layer: Defines the lowest level writer interface *)
signature PRIM_IO = sig
  type writer = { writeVec: string -> int }
end

structure PrimIO : PRIM_IO = struct
  type writer = { writeVec: string -> int }
end

(* 2. StreamIO Layer: Handles buffering and low-level stream state *)
signature STREAM_IO = sig
  type outstream
  val output : outstream * string -> unit
  val flushOut : outstream -> unit
  val mkOutstream : PrimIO.writer -> outstream
end

functor StreamIO (P: PRIM_IO) : STREAM_IO = struct
  (* We simulate a buffer using a string ref *)
  type outstream = { writer: P.writer, buf: string ref }

  fun mkOutstream w = { writer = w, buf = ref "" }

  fun output (os: outstream, s: string) =
    let
      val {writer, buf} = os
    in
      (* Simple buffering: just accumulate the string *)
      buf := !buf ^ s
    end

  fun flushOut (os: outstream) =
    let
      val {writer, buf} = os
      val s = !buf
    in
      if s <> "" then
        (ignore (#writeVec writer s);
         buf := "")
      else ()
    end
end

(* 3. ImperativeIO Layer: Provides mutable, stateful streams on top of StreamIO *)
signature IMPERATIVE_IO = sig
  type outstream
  val output : outstream * string -> unit
  val flushOut : outstream -> unit
  val mkOutstream : PrimIO.writer -> outstream
end

functor ImperativeIO (S: STREAM_IO) : IMPERATIVE_IO = struct
  (* Wraps the stream in a ref so it can be updated mutably as it's read/written *)
  type outstream = S.outstream ref

  fun mkOutstream w = ref (S.mkOutstream w)

  fun output (os: outstream, s: string) = S.output (!os, s)
  fun flushOut (os: outstream) = S.flushOut (!os)
end

(* Instantiate the functors to create our layered IO stack *)
structure MyStreamIO = StreamIO(PrimIO)
structure MyImperativeIO = ImperativeIO(MyStreamIO)

(* 4. TextIO Layer: The high-level structure that provides the standard interface *)
structure MyTextIO = struct
  open MyImperativeIO

  (* This simulates the FFI call by using the standard Basis Posix module, 
     which itself eventually bottoms out in `write(2)` *)
  fun posixWrite (s: string) : int =
    let
      val slice = Word8VectorSlice.full (Byte.stringToBytes s)
    in
      Posix.IO.writeVec (Posix.FileSys.stdout, slice)
    end

  val stdOut = mkOutstream { writeVec = posixWrite }

  fun print (s: string) = (output (stdOut, s); flushOut stdOut)
end

(* 5. Top-level alias *)
val my_print = MyTextIO.print

val () = my_print "Hello from the self-contained layered print implementation!\n"
