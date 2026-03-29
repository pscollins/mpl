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

local
   val v_base = Var.newNoname ()
   val v_val = Var.newNoname ()
   val stmt = Statement.Update {base = Base.Object v_base, offset = 0, value = v_val, writeBarrier = false}
in
   val _ = assert ("extractUses update has v_base", fn () => VarSet.contains (extractUses stmt, v_base))
   val _ = assert ("extractUses update has v_val", fn () => VarSet.contains (extractUses stmt, v_val))
   val _ = assert ("extractDefs update is empty", fn () => VarSet.isEmpty (extractDefs stmt))
end

local
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val v3 = Var.newNoname ()
   val stmt = Statement.Bind {exp = Exp.Object {args = Vector.fromList [v1, v2], con = NONE},
                              ty = Type.unit,
                              var = SOME v3}
in
   val _ = assert ("extractUses object has v1", fn () => VarSet.contains (extractUses stmt, v1))
   val _ = assert ("extractUses object has v2", fn () => VarSet.contains (extractUses stmt, v2))
   val _ = assert ("extractDefs object has v3", fn () => VarSet.contains (extractDefs stmt, v3))
end

local
   val {graph, getNode, getVar} = UseDefGraph.new ()
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val n1 = getNode v1
   val n2 = getNode v2
in
   val _ = assert ("getVar n1 is v1", fn () => Var.equals (getVar n1, v1))
   val _ = assert ("getVar n2 is v2", fn () => Var.equals (getVar n2, v2))
   val _ = assert ("n1 and n2 are different", fn () => not (DirectedGraph.Node.equals (n1, n2)))
   val _ = assert ("getNode v1 is idempotent", fn () => DirectedGraph.Node.equals (getNode v1, n1))
end

val _ = print "All RewriteSsa2 tests passed!\n"
