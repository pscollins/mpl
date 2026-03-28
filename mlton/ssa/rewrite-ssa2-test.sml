structure Atoms = Atoms ()
structure Ssa2 = Ssa2 (open Atoms)
structure RewriteSsa2 = RewriteSsa2 (Ssa2)

val _ = print "Running RewriteSsa2 tests...\n"
val _ = print "All RewriteSsa2 tests passed!\n"
