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

fun setContains (vs: VarSet.t) (v: Var.t): bool = let
   val single = VarSet.singleton v
   val intersect = VarSet.intersect (vs, single)
in
   not (VarSet.isEmpty intersect)
end

fun collectVarsBoundToPred (prog: Dec.t list vector, pred) = let
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
   Vector.fold (prog, VarSet.empty, collectVarsInDecs)
end

fun mapExps (prog: Dec.t list vector, rewrite: Exp.node -> Exp.node option):
    CoreML.Dec.t list vector = let
      val currStmt = ref 0
      fun doExp (exp: Exp.t) = let
         val (node: Exp.node, ty: Type.t) = Exp.dest exp
         fun doCaseRules rules = let
            fun doCaseRule {exp, layPat, pat, regionPat} =
                {exp = doExp exp,
                 layPat = layPat,
                 pat = pat,
                 regionPat = regionPat}
         in
            Vector.map (rules, doCaseRule)
         end
         fun doExpNodeImpl (expNode: Exp.node): Exp.node =
             case expNode of
                 Exp.App {func, arg, inline} =>
                 Exp.App {func = doExp func,
                          arg = doExp arg,
                          inline = inline}
               | Exp.Case {
                    ctxt, kind, nest, matchDiags,
                    noMatch, region, rules, test} =>
                 Exp.Case {
                    ctxt = ctxt, kind = kind, nest = nest,
                    matchDiags = matchDiags, noMatch = noMatch,
                    region = region, rules = doCaseRules rules,
                    test = doExp test}
               | Exp.Con _ => expNode (* constructor can't contain Exp.node *)
               | Exp.Const _ => expNode     (* const can't contain Exp.node *)
               | Exp.EnterLeave (exp, loc) =>
                 Exp.EnterLeave (doExp exp, loc)
               | Exp.Handle {catch, handler, try} =>
                 Exp.Handle {catch = catch,
                             handler = doExp handler,
                             try = doExp try}
               | Exp.Lambda l => Exp.Lambda (doLambda l)
               | Exp.Let (decs, exp) =>
                 Exp.Let (Vector.map (decs, doDec), doExp exp)
               | Exp.List exps => Exp.List (Vector.map (exps, doExp))
               | Exp.PrimApp {args, prim, targs} =>
                 Exp.PrimApp {args = Vector.map (args, doExp),
                              prim = prim,
                              targs = targs}
               | Exp.Raise exp => Exp.Raise (doExp exp)
               | Exp.Record elts => Exp.Record (Record.map (elts, doExp))
               | Exp.Seq exps => Exp.Seq (Vector.map (exps, doExp))
               | Exp.Var _ => expNode (* no inner Exp.node *)
               | Exp.Vector exps => Exp.Vector (Vector.map (exps, doExp))
         fun doExpNode (expNode: Exp.node): Exp.node =
             case (rewrite expNode) of
               (* The rewrite matched, apply it *)
                SOME result => result
              (* Otheerwise, recurse *)
              | NONE => doExpNodeImpl expNode

      in
         Exp.make (doExpNode node, ty)
      end
      and doLambda (l: Lambda.t) =
         let
            val {arg, argType, body, inline} = Lambda.dest l
         in
            Lambda.make {arg = arg, argType = argType, body = doExp body, inline = inline}
         end
      and doVbs vbs = let
         (* value binding *)
         fun doVb {ctxt, exp, layPat, nest, pat, regionPat} =
             {ctxt = ctxt,
              exp = doExp exp,
              layPat = layPat,
              nest = nest,
              pat = pat,
              regionPat = regionPat}
      in
         Vector.map (vbs, doVb)
      end
      and doRvbs rvbs = let
         (* "recursive value binding" *)
         fun doRvb {lambda, var} =
             {lambda = doLambda lambda, var = var}
      in
         Vector.map (rvbs, doRvb)
      end
      and doFun {decs, tyvars} = let
         fun doFunDec {lambda, var} = {lambda = doLambda lambda, var = var}
      in
         {decs = Vector.map (decs, doFunDec), tyvars = tyvars}
      end
      and doDec (dec: Dec.t): Dec.t =
          case dec of
              Dec.Val {matchDiags, rvbs, tyvars, vbs} =>
              Dec.Val {matchDiags = matchDiags,
                       rvbs = doRvbs rvbs,
                       tyvars = tyvars,
                       vbs = doVbs vbs}
            | Dec.Fun funDec => Dec.Fun (doFun funDec)
            | Dec.Datatype _ => dec  (* no Exp.node *)
            | Dec.Exception _ => dec (* no Exp.node *)
      fun doDecs (decs: Dec.t list): Dec.t list = List.map (decs, doDec)
   in
      Vector.map (prog, doDecs)
   end

(* Implementation detail of `inlineSourceMarkCall`: checks if `exp` is a `Var`
node that blongs to the provided `VarSet`. *)
fun isTargetVarExp (vs: VarSet.t) (exp: Exp.t): bool =
    case Exp.node exp of 
        Exp.Var (getVar, getTypes) => setContains vs (getVar())
     |  _ => false

fun inlineSourceMarkCall (vs: VarSet.t) (node: Exp.node): Exp.node option = let
   val isTargetVarExp = isTargetVarExp vs
in
   case node of
       Exp.App {func, arg, ...} =>
       if isTargetVarExp func then
          SOME (Exp.PrimApp {args = Vector.new1 (arg),
                             prim = Prim.Trace_sourceMark,
                             targs = Vector.new0 ()})
       else NONE
    |  _ => NONE
end

val inlineSourceMarkValueCall = ()

fun convertSourceMarkToStatic (node: Exp.node): Exp.node option = let
   fun getCleanName getConst = let
      val s = Const.toString (getConst())
   in
      (* The `Const` name shows up as `"name"` rather than `name`: drop it here. *)
      String.substring (s, 1, String.length s - 2)
   end
   fun getConstStr (exp: Exp.t) =
       case Exp.node exp of
           (* TODO(pscollins): Validate that the type is actually `string`. I
           think at this point we have already type-checked so it doesn't really
           matter. *)
           Exp.Const getConst => SOME (getCleanName getConst)
         | _ => NONE
   fun maybeBuildStaticMark (arg: string option) =
       case arg of
           SOME str => SOME (Exp.PrimApp {args = Vector.new0(),
                                          prim = Prim.Trace_staticSourceMark str,
                                          targs = Vector.new0()})
         | _ => NONE
in
   case node of
       Exp.PrimApp {args = args, prim = Prim.Trace_sourceMark, targs = targs} =>
       if Vector.length args = 1 andalso
          Vector.length targs = 0 then
          maybeBuildStaticMark (getConstStr (Vector.first args))
       else NONE
     | _ => NONE
end

fun decId (decs: Dec.t list): Dec.t list = decs

end
