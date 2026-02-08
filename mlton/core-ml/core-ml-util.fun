(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor CoreMLUtil (S: CORE_ML_UTIL_STRUCTS): CORE_ML_UTIL =
struct

open S
open CoreML

structure VarSet =
   UniqueSet (structure Element = Var
              val cacheSize = 1024
              val bits = 10)


fun collectVarsBoundToPred (decss: Dec.t list vector, pred) = let
   fun extractVb {exp, pat, ...}: (Var.t * Exp.t) option =
       case Pat.dest pat of
           (Pat.Var v, _) => SOME (v, exp)
         |  _ => NONE
   fun extractUniqueVb vbs: (Var.t * Exp.t) option =
       if Vector.length vbs = 1
       then extractVb (Vector.first vbs)
       else NONE
   fun extractUniqueDecBinding (dec: Dec.t): (Var.t * Exp.t) option =
       case dec of
           Dec.Val {vbs, ...} => extractUniqueVb vbs
         | _ => NONE
   fun collectVarsInDec (dec: Dec.t, vs: VarSet.t): VarSet.t =
       case (extractUniqueDecBinding dec) of
           NONE => vs
         | SOME (var, bind) =>
           if (pred bind) then VarSet.+ (vs, VarSet.singleton var)
           else vs
   fun collectVarsInDecs (decs: Dec.t list, vs: VarSet.t): VarSet.t =
       List.fold (decs, vs, collectVarsInDec)
in
   Vector.fold (decss, VarSet.empty, collectVarsInDecs)
end

fun decId (decs: Dec.t list): Dec.t list = decs

end
