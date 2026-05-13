signature SHALLOW_FLATTEN =
sig
   (* Exports:
        val transform: Program.t -> Program.t

     which iteratively runs `flattenOnce` until convergence. The behavior of
     this call is controlled by the following flags:

       -shallow-flatten-max-iters=N: limit the number of iterations to N

       -shallow-flatten-policy=maxWidth:$N sets the policy to `MaxWidth(n)`
    *)
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

   (* If the provided `Type.t` is an array or vector of tuples, returns the
   corresponding tuple of arrays or vectors, i.e.:

     ('a * 'b) array -> SOME ('a array * 'b array)
     ('a * 'b) vector -> SOME ('a vector * 'b vector)

     Otherwise, returns NONE.
    *)
   val maybeFlattenType: Type.t -> Type.t option

   (* Tracks flattening decisions for variables. *)
   type flattenedVars
   val newFlattenedVars: unit -> flattenedVars
   val destroyFlattenedVars: flattenedVars -> unit

   (* Marks the provided `Var.t` for flattening. It is only valid to call this
   function once  on a particular `(fv, v)` pair *)
   val markForFlatten: flattenedVars * Var.t -> unit
   (* If the provided `Var.t` was previously marked for flattening (above),
   returns true. Otherwise, returns false. *)
   val isMarkedForFlatten: flattenedVars * Var.t -> bool
   (* Returns the total number of variables marked for flattening *)
   val markedCount: flattenedVars -> int

   (* What array types should be flattened? *)
   datatype flattenPolicy =
        (* Flatten all tuple array types over <= `MaxWidth` tuple members *)
        MaxWidth of int

   (* Tracks types of `Var.t`s  *)
   type varTypes
   val newVarTypes: unit -> varTypes

   (* Sets the type for a future `getVarType` call. Must call at most once per
   `Var.t`. *)
   val setVarType: varTypes * Var.t * Type.t -> unit
   (* Returns the type set by a previous `setVarType` call. *)
   val getVarType: varTypes * Var.t -> Type.t

   (* Marks any vars in `Statement.t` that must be flattened according to the
   provided policy. The following statement types may induce flattening:

     * Any binding introducing a new array-typed variable:
       x: ('a * 'b ...) array = ...

     * Any argument (block or function) introducing a new array-typed variable:
       f(x: 'a * b * ... array, ...)

     * TODO(pscollins): More types?
    *)

   val markStatementForPolicy: (flattenedVars * flattenPolicy) ->
                               Statement.t -> unit
   val markArgForPolicy: (flattenedVars * flattenPolicy) ->
                         (Var.t * Type.t) -> unit


   (* If the provided `Var.t` is not marked for flattening, returns the original
   (var, type). Otherwise, returns (var, flattenedType), where `flattenedType`
   is flattened according to the rules of `maybeFlattenType`: if `type` is not
   flattenable, raises BadFlattenError. *)
   exception BadFlattenError
   val maybeFlattenArg: flattenedVars * (Var.t * Type.t) ->
                        Var.t * Type.t

   (* Flattens the provided `Statement.t` into a sequence of statements, if
   possible. Otherwise, returns NONE.

   All transformations below preserve any applicable flags (e.g. `raw` for
   `Array_alloc`, `readBarrier` for `Array_sub`, `writeBarrier` for
   `Array_update`).

   The following `PrimApp` expressions are flattenable:

     1. `Array_alloc` on tuple types
       x: ('a * 'b * ...) array = Array_alloc['a * 'b * ...](n)
       -->
       arr_a: 'a array = Array_alloc['a](n)
       arr_b: 'b array = Array_alloc['b](n)
       ...
       x: 'a array * 'b array * ... = tuple(arr_a, arr_b, ...)

    2. `Array_length` on tuple types:
      arr: ('a * 'b * ...) array = ...
      n: int = Array_length['a * b * ...](arr)
      -->
      (* by 1., arr is now 'a array * b array * ... *)
      arr_a = select (arr, 0)
      n: int = Array_length['a](arr)
      ...

    3. `Array_sub` on tuple types:
      arr: ('a * 'b * ...) array = ...
      x: ('a * 'b * ...) = Array_sub['a * 'b * ...](x, i)
      -->
      (* by 1., arr is now 'a array * b array * ... *)
      arr_a: 'a array = select (arr, 0)
      x_a: 'a =  Array_sub['a](arr_a, i)
      arr_b: 'b array = select (arr, 1)
      x_b: 'b =  Array_sub['b](arr_b, i)
      ...
      x: ('a * 'b * ...) = tuple(x_a, x_b, ...)

    4. `Array_update` on tuple types:
      arr: ('a * 'b * ...) array = ...
      x: ('a * 'b * ...) = ...
      _ = Array_update['a * 'b * ...](arr, i, x)
      -->
      (* by 1., arr is now 'a array * b array * ... *)
      arr_a: 'a array = select(arr, 0)
      x_a: 'a = select(x, 1)
      _ = Array_update['a])(arr_a, i, x_a)
      arr_b: 'b array = select(arr, 1)
      x_b: 'b = select(x, 2)
      _ = Array_update['b])(arr_b, i, x_b)
     ...

    5. `Array_toVector` on tuple types:
      arr: ('a * 'b * ...) array = ...
      vec: ('a * 'b * ...) vector = Array_toVector['a * 'b * ...](arr)
      -->
      (* by 1., arr is now 'a array * b array * ... *)
      arr_a: 'a array = select(arr, 0)
      vec_a: 'a vector = Array_toVector['a](arr_a)
      arr_b: 'b array = select(arr, 1)
      vec_b: 'b vector = Array_toVector['b](arr_b)
      ...
      vec: 'a vector * 'b vector * ... = tuple (vec_a, vec_b, ...)

    6. `Vector_length` on tuple types:
      vec: ('a * 'b * ...) vector = ...
      n: int = Vector_length['a * b * ...](vec)
      -->
      (* vec is now 'a vector * b vector * ... *)
      vec_a = select (vec, 0)
      n: int = Vector_length['a](vec_a)

    7. `Vector_sub` on tuple types:
      vec: ('a * 'b * ...) vector = ...
      x: ('a * 'b * ...) = Vector_sub['a * 'b * ...](vec, i)
      -->
      (* vec is now 'a vector * b vector * ... *)
      vec_a: 'a vector = select (vec, 0)
      x_a: 'a =  Vector_sub['a](vec_a, i)
      vec_b: 'b vector = select (vec, 1)
      x_b: 'b =  Vector_sub['b](vec_b, i)
      ...
      x: ('a * 'b * ...) = tuple(x_a, x_b, ...)

    For a non-`PrimApp` expression, flattening replaces a flattenable LHS type
    with the flattened equivalent,

    TODO: WRONG!

      x: ('a * b * ...) array = ...
      -->
      x: 'a array * 'b array ... = ...

    (and likewise for `vector`)
    *)
   val maybeFlattenStatement: Statement.t ->
                              Statement.t vector option

   (* Returns `true` if `Statement.` must be flattened.

      A statement must be flattened if it uses or defines a `Var.t` that must be
      flattened.
    *)
   val mustFlattenStatement: flattenedVars * Statement.t -> bool


   (* Flattens (according to the rules of `maybeFlattenStatement`) all
   statements in the provided `Statement.t vector` that require it (according to
   the rules of `mustFlattenStatement`).

   If some statement must be flattened, but cannot, raises
   `IllegalFlatteningDecision`.
    *)
   (* TODO: needs tests *)
   exception IllegalFlatteningDecision
   val flattenStatements: flattenedVars -> Statement.t vector ->
                          Statement.t vector
   (* Like above, but for arguments *)
   val flattenArgs: flattenedVars -> (Var.t * Type.t) vector ->
                    (Var.t * Type.t) vector

   (* Runs one iteration of flattening, collecting all flattenable array values
      and transforming them appropriately. Returns (SOME ...) if any value was
      successfully flattened, NONE otherwise.
    *)
   val flattenOnce: flattenPolicy -> Program.t -> Program.t option
end
