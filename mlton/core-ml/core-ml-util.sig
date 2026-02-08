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
      val collectVarsBoundToPred: (CoreML.Dec.t list vector * (CoreML.Exp.t -> bool)) -> VarSet.t

      val decId: CoreML.Dec.t list -> CoreML.Dec.t list
   end
