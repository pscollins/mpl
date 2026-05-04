functor ShallowFlatten (S: SSA_TRANSFORM_STRUCTS): SHALLOW_FLATTEN =
struct
open S

structure Queue =               (* TODO(gemini): fill in *)

type rewriter = {
   doStatements: Statement.t vector -> Statement.t vector,
   doArgs: (Var.t * Type.t) vector -> (Var.t * Type.t) vector,
   doTransfer: Transfer.t -> Transfer.t
}

fun rewriteBfs (r: rewriter) (p: Program.t): Program.t = let
   val {doStatements, doArgs, doTransfer} = r
   val Program.T {datatypes, functions, globals, main} = p
   val _ = Error.unimplemented "TODO"
in
   Program.T {datatypes = datatypes,
              functions = functions,
              globals = globals,
              main = main}

fun transform (p: Program.t): Program.t = p
end
