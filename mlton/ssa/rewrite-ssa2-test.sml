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

(* local *)
(*    val v1 = Var.newNoname () *)
(*    val v2 = Var.newNoname () *)
(*    val v3 = Var.newNoname () *)
(*    val v4 = Var.newNoname () *)
(*    val t = Type.unit *)
(*    (* s1: v2 = v1 *) *)
(*    val s1 = Statement.Bind {exp = Exp.Var v1, ty = t, var = SOME v2} *)
(*    (* s2: v3 = v2 *) *)
(*    val s2 = Statement.Bind {exp = Exp.Var v2, ty = t, var = SOME v3} *)
(*    (* s3: v4 = v3 *) *)
(*    val s3 = Statement.Bind {exp = Exp.Var v3, ty = t, var = SOME v4} *)
(*    val stmts = Vector.fromList [s1, s2, s3] *)

(*    fun containsVar (deps, v) = *)
(*        List.exists (deps, fn s => VarSet.contains (extractDefs s, v)) *)
(* in *)
(*    (* v1 is not defined in stmts *) *)
(*    val _ = assert ("getDependenciesDownwards v1 is empty", fn () => *)
(*       null (getDependenciesDownwards (stmts, v1))) *)

(*    (* v2 is defined by s1, s2 uses v2, s3 uses v3 (defined by s2) *) *)
(*    val _ = assert ("getDependenciesDownwards v2 has s1, s2, s3", fn () => *)
(*       let val deps = getDependenciesDownwards (stmts, v2) *)
(*       in containsVar (deps, v2) andalso containsVar (deps, v3) andalso containsVar (deps, v4) *)
(*       end) *)

(*    (* v3 is defined by s2, s3 uses v3 *) *)
(*    val _ = assert ("getDependenciesDownwards v3 has s2, s3", fn () => *)
(*       let val deps = getDependenciesDownwards (stmts, v3) *)
(*       in containsVar (deps, v3) andalso containsVar (deps, v4) andalso not (containsVar (deps, v2)) *)
(*       end) *)
(* end *)

val _ = print "All RewriteSsa2 tests passed!\n"
