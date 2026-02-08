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

      val decId: CoreML.Dec.t list -> CoreML.Dec.t list
   end
