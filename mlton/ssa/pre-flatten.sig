signature PRE_FLATTEN =
sig
   (* Exports:
        val transform: Program.t -> Program.t
    *)
   include SSA_TRANSFORM

   (* General IR manipulation utilities, exposed for testing *)
   type walker = {
      (* Hook to execute before visiting a function body *)
      beforeFunc: Function.t -> unit,
      (* Hook to execute after visiting a function body *)
      afterFunc: Function.t -> unit,
      (* Hook to execute before visiting a block body *)
      beforeBlock: Block.t -> unit,
      (* Hook to execute after visiting a block body *)
      afterBlock: Block.t -> unit,
      (* Hook to execute when visiting a statement *)
      statement: Statement.t -> unit
   }
   val doWalk: (walker * Program.t) -> unit

   type typedVar = Var.t * Type.t
   (* If the provided `typedVar` is a tuple type, returns a sequence of
   `typedVar`s that correspond to fresh `Var.t`s bound to the constituent types
   of the tuple. Otherwise, returns NONE. *)
   val flattenTupleVar: typedVar -> (typedVar vector) option

   (* Given a sequence of desired bindings and an original block `Label.t`,
   constructs a new `Block.t` that carries out the bindings and jumps to the
   original label. *)
   datatype bind =
            (* Reverse binding corresponding to flattening a tuple: `to` is the
            name for the tuple type, `froms` are the components of the tuple, in
            order. *)
            BindTuple of {to: typedVar, froms: Var.t vector}
   val buildBindBlock: bind vector * Label.t -> Block.t

   (* Describes how to modify each argument in `buildFlattenedFunction`  *)
   datatype argChoice =
            (* No modification: keep the existing argument *)
            Preserve
            (* Flatten a tuple argument into its constituent parts *)
          | FlattenTuple

   (* Given a `Function.t` and a set of flattening decisions for each argument,
   returns the (partially)-flattened function, i.e. given:

      {f (ab: (bool * bool), c: int): ..., [FlattenTuple]}

   Returns the modified function:

      f (a: bool, b: bool, c: int): ab = tuple (a, b); ....

   `argChoice` must be compatible with the function args (i.e. same count and
   applicable types): if not, error.
    *)
   val buildFlattenedFunction: (Function.t * argChoice vector) -> Function.t

   (* Validates the action of the supplied set of choices on the supplied
   function *)
   datatype flatteningChoiceType =
            (* Valid, but no change *)
              NoOp
            (* Valid, and corresponds to a real flattening *)
            | Valid
            (* Invalid: wrong arity or impossible flatten *)
            | Invalid
   val checkFlatteningChoice: (Function.t * argChoice vector) ->
                              flatteningChoiceType

   (* Flattening decision for a particular `Var.t` *)
   datatype varChoice =
            (* Don't flatten *)
            PreserveVar
            (* Flatten: carries the parent `Var.t`s to flatten-through.
            `parents` is guaranteed to be non-empty. *)
          | FlattenTupleVar of Var.t vector

   (* Type to manage tagging `Var.t`s with their flattening decision *)
   type varChoiceManager
   (* Creates a new `varChoiceManager` *)
   val newVarChoiceManager: unit -> varChoiceManager
   (* Sets the `varChoice` for any `Var.t`s in `Statement.t`:

     Flattenable `Var.t`s are of the form:

       var := tuple(p1, p2, p3) -> FlattenTupleVar ([p1, p2, p3])

     All other `Var.t`s are marked `PreserveVar`.
    *)
   val chooseVarsInStatement: (varChoiceManager * Statement.t) -> unit
   (* Returns the choice for the provided `Var.t` *)
   val getVarChoice: (varChoiceManager * Var.t) -> varChoice
   (* Cleans up state associated with the provided `varChoiceManager` *)
   val destroyVarChoiceManager: varChoiceManager -> unit
   (* Returns a `varChoiceManager` that carries flattening choices for all
   `Var.t`s  in the program. *)
   val newVarChoicesForProgram: Program.t -> varChoiceManager

   (* Manages mapping `Func.t`s to their flattened equivalents  *)
   type functionManager

   (* Creates a new `functionManager` over all of the `Func.t`s in the provided
   program. *)
   val newFunctionManager: Program.t -> functionManager

   (* Returns a `Func.t` that satisfies the given flattening decision:

      * If the flattening decision is NoOp, returns the input `Func.t`
      * If the flattening decision is `Valid`, returns a `Func.t` that has been
        flattened accordingly, adding it to the list of pending new functions
      * If the flattening decision is `Invalid`, crash.

      Crashes if the provided `Func.t` was not a part of the original
      `Program.t`: newly-returned `Func.t`s are not added to the mapping.
    *)
   val getOrCreateFunc: (functionManager *
                        Func.t *
                        argChoice vector) -> Func.t

   (* Returns the collection of `Function.t`s backing the newly-created
   `Func.t`s from calls to `getOrCreateFunc`, clearing the list of "pending new
   functions" as a side effect (i.e. for two consecutive calls, the second call
   will always return emtpy.) *)
   val extractNewFunctions: functionManager -> Function.t list
   (* Cleans up state associated with this object. If the list of pending new
   functions is not empty, error. *)
   val destroyFunctionManager: functionManager -> unit

end
