functor ShallowFlatten (S: SSA_TRANSFORM_STRUCTS): SHALLOW_FLATTEN =
struct
open S

type rewriter = {
   doStatements: Statement.t vector -> Statement.t vector,
   doArgs: (Var.t * Type.t),
   doTransfer: Transfer.t -> Transfer.t
}

fun rewriteBfs (r: rewriter) (p: Program.t): Program.t =
    Error.unimplemented "TODO"

fun transform (p: Program.t): Program.t = p
end
