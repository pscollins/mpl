signature SHALLOW_FLATTEN =
sig
   include SSA_TRANSFORM

   (* Interface for applying a transformation to a specified program *)
   type rewriter = {
      (* Transform the given statements (block body or globals) *)
      doStatements: Statement.t vector -> Statement.t vector,
      (* Transform the given typed variables (block or function arguments) *)
      doArgs: (Var.t * Type.t) vector -> (Var.t * Type.t) vector,
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


   (* Effectful version of the interface above *)
   type visitor = {
      foreachStatements: Statement.t vector -> unit,
      foreachArgs: (Var.t * Type.t) vector -> unit,
      foreachTransfer: Transfer.t -> unit
   }

   (* Like above, but for side-effecting expressions *)
   val foreachBfs: visitor -> Program.t -> unit

   (* If the provided `Type.t` is an array of tuples, returns the corresponding
   tuple of arrays, i.e.:

     ('a * 'b) array -> SOME ('a array * 'b array)

     Otherwise, returns NONE.
    *)
   val maybeFlattenType: Type.t -> Type.t option

   (* Tracks flattening decisions for variables. *)
   type flattenedVars
   val newFlattenedVars: unit -> flattenedVars
   (* Marks the provided `Var.t` for flattening *)
   val markForFlatten: flattenedVars * Var.t -> unit
   (* If the provided `Var.t` was previously marked for flattening (above),
   returns true. Otherwise, returns false. *)
   val isMarkedForFlatten: flattenedVars * Var.t -> bool

   exception BadFlattenError

   (* If the provided `Var.t` is not marked for flattening, returns the original
   (var, type). Otherwise, returns (var, flattenedType), where `flattenedType`
   is flattened according to the rules of `maybeFlattenType`: if `type` is not
   flattenable, raises BadFlattenError.
    *)
   val maybeFlattenArg: flattenedVars * (Var.t * Type.t) ->
                        Var.t * Type.t

   (* Flattens the provided `Statement.t` into a sequence of statements, if
   possible. Otherwise, returns NONE.

   The following expressions are flattenable:

     * `Array_alloc` on tuple types
      x: ('a * 'b * ...) array = Array_alloc['a * 'b * ...](n)
      -->
      arr_a: 'a array = Array_alloc['a](n)
      arr_b: 'b array = Array_alloc['b](n)
      ...
      x: 'a array * 'b array * ... = tuple(arr_a, arr_b, ...)
    *)

   val maybeFlattenStatement: Statement.t ->
                              Statement.t vector option
end
