functor RewriteSsa2 (S: SSA_TREE2): REWRITE_SSA2 =
struct
structure Ssa2 = S

open Ssa2

structure VarSet = UnorderedSet (Var)

fun extractUses (stmt: Statement.t): VarSet.t =
    VarSet.empty
        
fun extractDefs (stmt: Statement.t): VarSet.t =
    VarSet.empty

fun getDefIndex (stmts: Statement.t vector, v: Var.t): int option =
    NONE
        
end
