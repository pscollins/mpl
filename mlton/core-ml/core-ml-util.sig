(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature CORE_ML_UTIL_STRUCTS =
sig
   structure CoreML: CORE_ML
end

signature CORE_ML_UTIL =
   sig
      include CORE_ML_UTIL_STRUCTS

      structure VarSet: UNIQUE_SET where type Element.t = CoreML.Var.t

      (* Returns `true` if the provided `VarSet.t` contains the provided
      `Var.t`, otherwise `false`. *)
      val setContains: VarSet.t -> CoreML.Var.t -> bool

      (* Given a predicate and a snippet of top-level CoreML IR, find all
      `Var.t`s appearing in a `Val` binding (for now, only the non-recursive
      single-element `vbs` case is supported, `Fun` is not supported) bound to
      an expression satisfiying the predicate *)
      val collectVarsBoundToPred:
          (CoreML.Dec.t list vector * (CoreML.Exp.t -> bool)) -> VarSet.t

      (* Given a (partial) transformation on `Exp.node`s and a snippet of
      top-level CoreML IR, walk the tree and apply the transformation to each
      `Exp.node`: when the transformation returns `SOME (node)`, replace the
      current `Exp.node` with the result of the transformation: otherwise,
      recurse.*)
      val mapExps: (CoreML.Dec.t list vector * (CoreML.Exp.node -> CoreML.Exp.node option)) ->
                   CoreML.Dec.t list vector

      (* If the provided `Exp.node` is an `Exp.App` whose `func` is a singleton
      `Var` that belongs to the provided `VarSet.t`, then returns a `PrimApp`
      corresponding to a `Trace_sourceMark` applied to the same `arg` as the
      original `Exp.App`. Otherwise, returns `NONE`. *)
      val inlineSourceMarkCall:
          VarSet.t -> CoreML.Exp.node -> CoreML.Exp.node option

      (* Like above, but for `sourceMarkValue`: if the provided `Exp.node` is an
       `Exp.App` whose `func` is a singleton `Var` that belongs to the provided
       `VarSet.t`, then returns a `PrimApp` corresponding to a
       `Trace_sourceMarkValue` applied to the same (tuple) `arg` as the original
       `Exp.App`. Otherwise, returns `NONE` *)
      val inlineSourceMarkValueCall: unit
          (* VarSet.t -> CoreML.Exp.node -> CoreML.Exp.node option *)

      (* If the provided `Exp.node` is a `PrimApp` corresponding to a
      `Trace_sourceMark` with an `Exp.Const` argument of type string, then
      returns a `Trace_staticSourceMark` with a static `string` argument
      corresponding to the `Const` value and no runtime arguments. Otherwise,
      returns NONE. *)
      val convertSourceMarkToStatic:
          CoreML.Exp.node -> CoreML.Exp.node option

      (* The following function prints the specified IR type with explicit tags
      for the corresponding data type defined in `core-ml.fun`: this is intended
      as a format that is simpler to work back to SML constructor calls than the
      existing `layout` textual IR format.

      For example, a CoreML snippet corresponding to an SML expression like:

         datatype myT = MyConstructor of string

      prints out a literal representation of the corresponding `Dec.Datatype`
      record object, i.e.:

        Dec.Datatype {cons=[{....},...], tycon=...., tyvars=....}

      and so on, recursing down through each layer of CoreML datatype until a
      leaf type is reached.
       *)
      val toVerboseStringDec: CoreML.Dec.t -> string
      val toVerboseStringExp: CoreML.Exp.t -> string
      val toVerboseStringPat: CoreML.Pat.t -> string
      val toVerboseStringType: CoreML.Type.t -> string
   end
