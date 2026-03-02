(* Copyright (C) 2026 Patrick Lu.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature TRACE_HEAP_OPS_STRUCTS =
   sig
      include RSSA_TRANSFORM_STRUCTS
   end

signature TRACE_HEAP_OPS =
   sig
      include TRACE_HEAP_OPS_STRUCTS

      (* The functions below (except for `transform`) are implementation details
      of this pass, exposed here for testing. *)

      (* Given a `Program.t` and a predicate on `Statement.t`s, returns all of
      the statements that match the predicate. *)
      val filterStatements:
          (Program.t * (Statement.t -> bool)) ->
          Statement.t list

      (* Given a `Program.t` and a (partial) transformation on `Statement.t`s,
      returns a `Program.t` resulting from applying the transformation on every
      `Statement.t` in the `Program.t` and replacing for the non-`NONE` results. *)
      val mapStatements:
          (Program.t * (Statement.t -> Statement.t option)) ->
          Program.t


      (* Given:

          (program, initial, f)

        Returns the result of;

           fold (flattenToStatements program, initial, f)
       *)
      val foldStatements:
          (Program.t * 'a * (Statement.t * 'a -> 'a)) ->
          'a
 
      (* Converts a list of statements into a string representation. *)
      val statementsToString: Statement.t list -> string

      structure VarSet: SET
      sharing type VarSet.Element.t = Var.t
 
      (* Returns `true` if the provided `Operand.t` is "heap-accessing."

       For an `Operand` `o`, "heap-accessing" is defined as follows:

        If `o` is a `Var`, `Const` or `Cast`, then it is not "heap-accessing."
        All other `Operand`s are "heap-accessing."
      *)
      val isForbiddenHeapOperand: Operand.t -> bool

      (* Collects all `Var.t`s that correspond to "heap-accessing" values. For
      now, only covers `Var.t`s that are directly defined as an alias for a
      "heap-accessing" `Operand.t` in a `Bind` statement.

      TODO(pscollins): Consider if this check needs to be more aggressive
       *)
      val collectForbiddenHeapVars: Program.t -> VarSet.t

      (* Returns `true` if the supplied `Statement.t`, `s` is a "heap operation"
      that is forbidden by a `noHeap` statement.

      For now, a "forbidden heap operation" is defined as follows:

        If `s` is a `Trace_noHeap` `PrimApp` whose `Operand` is
        "heap-accessing", or an alias of a "heap-acessing" operand provided in
        the `VarSet.t` -> `true`. Otherwise, `false`.

     and for an `Operand` "heap-accessing" is defined as above.

     TODO(pscollins): Revisit these definitions.
      *)
      val isForbiddenHeapOp: VarSet.t -> Statement.t -> bool

      (* If the provided `Statement.t` `s` is a `Trace_noHeap` `PrimApp`,
      returns `SOME s'`, where `s'` is a `Bind` that performs a 'copy'
      equivalent to the  original `PrimApp`, i.e.:

        PrimApp (args=[arg], dst=(SOME d), prim=Trace_noHeap)
          -->
        Bind (dst=d, src=arg, pinned=false)

      Otherwise, `NONE`.
       *)
      val maybeElideNoHeap: Statement.t -> Statement.t option

      (* Like above, but for `Trace_heapOK

        PrimApp (args=[arg], dst=(SOME d), prim=Trace_HeapOk)
          -->
        Bind (dst=d, src=arg, pinned=false)
       *)
      val maybeElideHeapOk: Statement.t -> Statement.t option

      (* If the provided `Program.t` contains any statements satisfying
      `isForbiddenHeapOp`, raise an error.

      Otherwise, rewrite any `Trace_noHeap` `Statement.t`s according to the
      rules of `maybeElideNoHeap` + `maybeElideHeapOk`.*)
      val transform: Program.t -> Program.t
   end
