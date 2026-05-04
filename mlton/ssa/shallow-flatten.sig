signature SHALLOW_FLATTEN =
sig
   include SSA_TRANSFORM

   (* Interface for applying a transformation to a specified program *)
   type rewriter = {
      (* Transform the given statements (block body or globals) *)
      doStatements: Statement.t vector -> Statement.t vector,
      (* Transform the given typed variables (block or function arguments) *)
      doArgs: (Var.t * Type.t) -> (Var.t * Type.t),
      (* Transform the given transfer *)
      doTransfer: Transfer.t -> Transfer.t
   }

   (* Applies `rewriter` to the `Program.t`

      Guarantees that all constructs are visited in BFS order, i.e. the
      definition of any `Var.t` is always visted before its use. Consequently:

        * Globals are visited before any `Function.t`
        * `Function.t`s are visited in some topological order
        * The args of a `Function.t` are visited before any block in the
          `Function.t`
        * `Block.t`s within a function are visited in some topological order
        * `Block.t` arguments are visited before any statement in the block body
        * Every program construct is visited, even if the program CFG is disconnected
   *)
   val rewriteBfs: rewriter -> Program.t -> Program.t
end
