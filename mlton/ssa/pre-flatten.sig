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
end
