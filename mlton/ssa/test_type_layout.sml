
structure Atoms = Atoms ()
structure Ssa = Ssa (open Atoms)

val _ = let
  open Ssa
  val w32 = WordSize.word32
  val t1 = Type.word w32
  val t2 = Type.array t1
  val t3 = Type.array t2

  fun printType t =
    print (Layout.toString (Type.layout t) ^ "\n")

  val _ = print "word32: "
  val _ = printType t1
  val _ = print "word32 array: "
  val _ = printType t2
  val _ = print "word32 array array: "
  val _ = printType t3
in
  ()
end
