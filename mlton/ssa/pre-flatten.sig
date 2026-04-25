signature PRE_FLATTEN =
sig
   (* Exports:
        val transform: Program.t -> Program.t

     which iteratively runs `flattenOnce` until convergence. The behavior of
     this call is controlled by the following flags:

       -pre-flatten-max-iters=N: limit the number of iterations to N

       -pre-flatten-consumer-policy={always|any_unpack|all_unpack}:
          sets the `flatteningPolicy` (below)

       -pre-flatten-resolve-policy={local|global}:
          sets the `resolvePolicy` (below)

       -pre-flatten-types-policy={any|tuple|con}
          sets the `flattenableTypesPolicy` (below)
    *)
   include SSA_TRANSFORM

   (* General IR manipulation utilities, exposed for testing *)

   (* Utility to apply a side-effecting expression at each level of the
      program *)
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

   (* Applies the provided function to each `Block.t` in the program, updating
   the containing `Function.t` for any instances that return SOME (..). *)
   val mapBlocks: (Program.t * (Block.t -> Block.t option)) -> Program.t

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
            (* Reverse binding corresponding to flattening a `ConApp`: `to` is
            the name for the constructed object, `froms` are the components of
            the tuple, in order, and `con` is the constructor. *)
            | BindCon of {to: typedVar, froms: Var.t vector, con: Con.t}

   val buildBindBlock: bind vector * Label.t -> Block.t

   (* Describes how to modify each argument in `buildFlattenedFunction`  *)
   datatype argChoice =
            (* No modification: keep the existing argument *)
            Preserve
            (* Flatten a tuple argument into its constituent parts *)
            | FlattenTuple
            (* Flatten a datatpe argument into its constituent parts for the
            specified constructor.*)
            | FlattenCon of {argTys: Type.t vector, con: Con.t}

   (* Compares two `argChoice`s for equality *)
   val choiceEqual: argChoice * argChoice -> bool

   (* Given a `Function.t` and a set of flattening decisions for each argument,
   returns the (partially)-flattened function, i.e. given:

      {f (ab: (bool * bool), c: int): ..., [Flatten]}

   Returns the modified function:

      f (a: bool, b: bool, c: int): ab = tuple (a, b); ....

   Or, for, the ConApp case

      {f (ab: (Ty of bool * bool), c: int): ..., [Flatten]}
        -->
      f (a: bool, b: bool, c: int): ab = con Ty (a, b); ....

   `argChoice` must be compatible with the function args (i.e. same count and
   applicable types): if not, error.

   The returned function is guaranteed to have a new name, and all of the
   variables within it are guarnateed to be distinct from the original function.
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
            (* Flatten: carries the parent constructpr + typed `Var.t`s to
            flatten-through *)
            | FlattenConVar of {args: (Var.t * Type.t) vector, con: Con.t}

   (* Type to manage tagging `Var.t`s with their flattening decision and other
   associated data *)
   (* TODO(pscollins): Rename? `varDataManager`? *)
   type varChoiceManager
   (* Creates a new `varChoiceManager` *)
   val newVarChoiceManager: unit -> varChoiceManager
   (* Sets the `varChoice` for any `Var.t`s in `Statement.t`:

     Flattenable tuple `Var.t`s are of the form:

       var := tuple(p1, p2, p3) -> FlattenTupleVar ([p1, p2, p3])

     Flattenable datatype `Var.t`s are of the form:

       var := con (p1, p2, p3) -> FlattenConVar ([[p1, p2, p3])

     All other `Var.t`s are marked `PreserveVar`.
    *)
   val chooseVarsInStatement: (varChoiceManager * Statement.t) -> unit
   (* Returns the choice for the provided `Var.t` *)
   val getVarChoice: (varChoiceManager * Var.t) -> varChoice
   (* Cleans up state associated with the provided object *)
   val destroyVarChoiceManager: varChoiceManager -> unit
   (* Returns a `varChoiceManager` that carries flattening choices for all
   `Var.t`s  in the program. *)
   val newVarChoicesForProgram: Program.t -> varChoiceManager
   (* Exposed for testing: records the type of any binding in `Statement.t` for
   use in a future `chooseVarsInStatement` call *)
   val markTypeForBinding: (varChoiceManager * Statement.t) -> unit

   (* Describes how a `Var.t` is consumed by a particular reader. *)
   datatype varConsumer =
            (* The consumer is an unpack operation (i.e. tuple select) *)
            AsUnpacked
            (* The consumer is a non-call operation that takes the entire tuple
            object *)
            | AsCurrent
            (* The consumer behavior follows the behavior of the provided
            `Var.t`, e.g. this `Var.t` binds to it through a function call. *)
            | AsAlias of Var.t

   (* Manages tagging `Var.t`s with their `varConsumer` lists *)
   type varConsumerManager
   (* Creates a new `varConsumerManager` over the specified program *)
   val newVarConsumerManager: Program.t -> varConsumerManager
   (* Marks the `varConsumer`s for each used `Var.t` in the provided
   `Statement.t` *)
   val markConsumersInStatement: (varConsumerManager * Statement.t) -> unit
   (* Marks the `varConsumer`s for each `Var.t` in the provided `Transfer.t`: a
   `Transfer.t` can only induce an `AsAlias` relationship. *)
   val markConsumersInTransfer: (varConsumerManager * Transfer.t) -> unit
   (* Returns the `varConsumer` tags for each consumer of the provided `Var.t` *)
   val getVarConsumers: (varConsumerManager * Var.t) -> varConsumer list
   (* Cleans up state associated with the provided object *)
   val destroyVarConsumerManager: varConsumerManager -> unit
   (* Returns a `varConsumerManager` that carries all the `varConsumer`
   information for the specified `Program.t` *)
   val newVarConsumersForProgram: Program.t -> varConsumerManager

   (* Exposed for testing: initializes a `varConsumerManager` with the specified
   consumers attached to the provided `Var.t`s *)
   val newVarConsumerManagerFromAssignments:
       (Var.t * (varConsumer list)) list ->
       varConsumerManager

   (* Policy describing how to resolve `AsAlias` statements. *)
   datatype varAliasPolicy =
            (* Remove `AsAlias` statements from the list *)
            DropAlias
            (* Traverse the `AsAlias` graph to union all results together *)
            | UnionAlias
   (* Resolves aliases in the `varConsumer` list according to the specified
   policy *)
   val resolveAliases: (varAliasPolicy * varConsumerManager) ->
                       varConsumer list ->
                       varConsumer list


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

   (* Describes how we choose to flatten functions: for the description below,
   we'll assume that we have a function definition

       f(arg1, arg2, arg3, ...): ...

    and we want to choose the appropriate flattening at the callsite:

       f(x1, x2, x3, ...)

    In this case, we say that `arg[i]` is "flattenable" (at this particular
    callsite) whenever the corresponding `x[i]` is "flattenable", i.e. when
    `varChoice` for the corresponding `x[i]` is not `PreserveVar`.
    *)
   datatype flatteningPolicy =
            (* Flatten `arg[i]` as much as possible, i.e. whenever `x[i]` is
            flattenable *)
            FlattenAlways
            (* Flatten `arg[i]` when `x[i]` is flattenable and at least one
             consumer of `arg[i]` is `AsUnpacked` *)
            | FlattenForAnyUnpack
            (* Flatten `arg[i]` when `x[i]` is flattenable and every consumer of
             `arg[i]` is `AsUnpacked` (satisfied vacuously by an empty consumer
             list) *)
            | FlattenForAllUnpack

   (* TODO(pscollins): Try more heuristics *)

   (* Given the `varChoice` and `varConsumer` list corresponding to a particular
   `x[i]` and `arg[i]` (described above), updates `varChoice` to account for the
   specified policy.

   Must run *after* resolving aliases: if any `varConsumer` is `AsAlias`, error.
    *)
   val updateChoiceForPolicy: flatteningPolicy ->
                              (varChoice * (varConsumer list)) ->
                              varChoice

   (* Chooses which datatypes can be flattened through *)
   datatype flattenableTypesPolicy =
            (* Allows flattening any type (tuple or ConApp) *)
              FlattenAnyType
            (* Flatten through tuple constructors only *)
            | FlattenOnlyTuple
            (* Flatten through ConApp only *)
            | FlattenOnlyConApp

   (* Updates the provided `varChoice` according to the policy: unsupported
   types become `Preserve` *)
   val updateChoiceForAllowedTypes: flattenableTypesPolicy ->
                                    varChoice -> varChoice

   (* Runs one iteration of flattening: for each appearance of the sequence:

       x = tuple(t1, t2, ...)
       f(x, arg2, ...)

      where `f` is defined as:

        f(arg1, arg2, ...):
          ...

      replaces the call to `f` with an equivalent flattened version, i.e.:

       f_flat(t1, t2, ..., arg2, ...):
         arg1 = tuple(t1, t2, ...)
         ...original body of `f`...

     Similarly, for ConApp flattening, finds a sequence like:

       x = con MyCon (t1, t2, ...)
       f(x, arg2, ...)

     and replaces this call to `f` with an equivalent call to a flattened
     version, i.e.:

       f_flat(t1, t2, ..., arg2)
         arg1 = con MyCon (t1, t2, ...)
         ...original body of `f`...

     On success (i.e. if we made progress and flattened at least one function),
     returns `SOME ...`, otherwise, returns `NONE`.

     Flattening decisions are subject to the described `flatteningPolicy`,
     outlined above, with consumer information resolved according to
     `varAliasPolicy` (above).
    *)
   val flattenOnce: flatteningPolicy * varAliasPolicy * flattenableTypesPolicy -> Program.t -> Program.t option

end
