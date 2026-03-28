structure Atoms = Atoms ()
structure Ssa2 = Ssa2 (open Atoms)
structure RewriteSsa2 = RewriteSsa2 (Ssa2)

open RewriteSsa2

val _ = print "Running RewriteSsa2 tests...\n"

fun assert (msg, f) =
    if f () then ()
    else (print ("Assertion failed: " ^ msg ^ "\n");
          OS.Process.exit OS.Process.failure)

local
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val s0 = VarSet.empty
   val s1 = VarSet.singleton v1
   val s2 = VarSet.add (s1, v2)
in
   val _ = assert ("s0 empty", fn () => VarSet.isEmpty s0)
   val _ = assert ("s1 has v1", fn () => VarSet.contains (s1, v1))
   val _ = assert ("s1 not has v2", fn () => not (VarSet.contains (s1, v2)))
   val _ = assert ("s2 has v1", fn () => VarSet.contains (s2, v1))
   val _ = assert ("s2 has v2", fn () => VarSet.contains (s2, v2))
   val _ = assert ("s2 size 2", fn () => VarSet.size s2 = 2)
end

local
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val t = Type.unit
   val stmt = Statement.Bind {exp = Exp.Var v1, ty = t, var = SOME v2}
in
   val _ = assert ("extractUses bind has v1", fn () => VarSet.contains (extractUses stmt, v1))
   val _ = assert ("extractDefs bind has v2", fn () => VarSet.contains (extractDefs stmt, v2))
   val _ = assert ("getDefIndex find v2", fn () => getDefIndex (Vector.fromList [stmt], v2) = SOME 0)
end

val _ = print "All RewriteSsa2 tests passed!\n"
