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

fun v2s (v, f) = "[" ^ (String.concatWith (Vector.toList (Vector.map (v, f)), ", ")) ^ "]"
fun o2s (opt, f) = case opt of NONE => "NONE" | SOME x => "SOME (" ^ (f x) ^ ")"

fun ty2s ty = Layout.toString (Type.layout ty)
fun var2s v = Var.toString v
fun con2s c = Con.toString c
fun tycon2s t = Tycon.toString t
fun tyvar2s t = Tyvar.toString t
fun const2s c = Const.toString (c ())
fun field2s f = Field.toString f

fun record2s (r, f) =
   let
      val elts = Record.toVector r
      fun elt2s (field, x) = "(" ^ (field2s field) ^ ", " ^ (f x) ^ ")"
   in
      v2s (elts, elt2s)
   end

fun pat2s p =
   let val (node, ty) = Pat.dest p
   in "Pat.make (" ^ (patNode2s node) ^ ", " ^ (ty2s ty) ^ ")"
   end
and patNode2s node =
   case node of
      Pat.Con {arg, con, targs} =>
         "Pat.Con {arg=" ^ (o2s (arg, pat2s)) ^
         ", con=" ^ (con2s con) ^
         ", targs=" ^ (v2s (targs, ty2s)) ^ "}"
    | Pat.Const c => "Pat.Const (" ^ (const2s c) ^ ")"
    | Pat.Layered (v, p) => "Pat.Layered (" ^ (var2s v) ^ ", " ^ (pat2s p) ^ ")"
    | Pat.List ps => "Pat.List " ^ (v2s (ps, pat2s))
    | Pat.Or ps => "Pat.Or " ^ (v2s (ps, pat2s))
    | Pat.Record r => "Pat.Record " ^ (record2s (r, pat2s))
    | Pat.Var v => "Pat.Var " ^ (var2s v)
    | Pat.Vector ps => "Pat.Vector " ^ (v2s (ps, pat2s))
    | Pat.Wild => "Pat.Wild"

and exp2s e =
   let val (node, ty) = Exp.dest e
   in "Exp.make (" ^ (expNode2s node) ^ ", " ^ (ty2s ty) ^ ")"
   end
and expNode2s node =
   case node of
      Exp.App {func, arg, ...} =>
         "Exp.App {func=" ^ (exp2s func) ^ ", arg=" ^ (exp2s arg) ^ ", ...}"
    | Exp.Case {rules, test, ...} =>
         "Exp.Case {rules=" ^ (v2s (rules, rule2s)) ^ ", test=" ^ (exp2s test) ^ ", ...}"
    | Exp.Con (con, targs) =>
         "Exp.Con (" ^ (con2s con) ^ ", " ^ (v2s (targs, ty2s)) ^ ")"
    | Exp.Const c => "Exp.Const (" ^ (const2s c) ^ ")"
    | Exp.EnterLeave (e, _) => "Exp.EnterLeave (" ^ (exp2s e) ^ ", ...)"
    | Exp.Handle {catch=(v, ty), handler, try} =>
         "Exp.Handle {catch=(" ^ (var2s v) ^ ", " ^ (ty2s ty) ^ "), handler=" ^ (exp2s handler) ^ ", try=" ^ (exp2s try) ^ "}"
    | Exp.Lambda l => "Exp.Lambda (" ^ (lambda2s l) ^ ")"
    | Exp.Let (decs, e) =>
         "Exp.Let (" ^ (v2s (decs, dec2s)) ^ ", " ^ (exp2s e) ^ ")"
    | Exp.List es => "Exp.List " ^ (v2s (es, exp2s))
    | Exp.PrimApp {args, prim, targs} =>
         "Exp.PrimApp {args=" ^ (v2s (args, exp2s)) ^ ", prim=" ^ (Prim.toString prim) ^ ", targs=" ^ (v2s (targs, ty2s)) ^ "}"
    | Exp.Raise e => "Exp.Raise (" ^ (exp2s e) ^ ")"
    | Exp.Record r => "Exp.Record " ^ (record2s (r, exp2s))
    | Exp.Seq es => "Exp.Seq " ^ (v2s (es, exp2s))
    | Exp.Var (v, targs) => "Exp.Var (" ^ (var2s (v ())) ^ ", " ^ (v2s (targs (), ty2s)) ^ ")"
    | Exp.Vector es => "Exp.Vector " ^ (v2s (es, exp2s))

and rule2s {exp, pat, ...} =
   "{exp=" ^ (exp2s exp) ^ ", pat=" ^ (pat2s pat) ^ ", ...}"

and lambda2s l =
   let val {arg, argType, body, ...} = Lambda.dest l
   in "Lambda.make {arg=" ^ (var2s arg) ^ ", argType=" ^ (ty2s argType) ^ ", body=" ^ (exp2s body) ^ ", ...}"
   end

and dec2s d =
   case d of
      Dec.Datatype v =>
         "Dec.Datatype " ^ (v2s (v, fn {cons, tycon, tyvars} =>
            "{cons=" ^ (v2s (cons, fn {arg, con} => "{arg=" ^ (o2s (arg, ty2s)) ^ ", con=" ^ (con2s con) ^ "}")) ^
            ", tycon=" ^ (tycon2s tycon) ^
            ", tyvars=" ^ (v2s (tyvars, tyvar2s)) ^ "}"))
    | Dec.Exception {arg, con, ...} =>
         "Dec.Exception {arg=" ^ (o2s (arg, ty2s)) ^ ", con=" ^ (con2s con) ^ ", ...}"
    | Dec.Fun {decs, tyvars} =>
         "Dec.Fun {decs=" ^ (v2s (decs, fn {lambda, var} => "{lambda=" ^ (lambda2s lambda) ^ ", var=" ^ (var2s var) ^ "}")) ^ 
         ", tyvars=" ^ (v2s (tyvars (), tyvar2s)) ^ "}"
    | Dec.Val {rvbs, vbs, tyvars, ...} =>
         "Dec.Val {rvbs=" ^ (v2s (rvbs, fn {lambda, var} => "{lambda=" ^ (lambda2s lambda) ^ ", var=" ^ (var2s var) ^ "}")) ^
         ", tyvars=" ^ (v2s (tyvars (), tyvar2s)) ^
         ", vbs=" ^ (v2s (vbs, fn {exp, pat, ...} => "{exp=" ^ (exp2s exp) ^ ", pat=" ^ (pat2s pat) ^ ", ...}")) ^ ", ...}"

val toVerboseStringDec = dec2s
fun toVerboseStringDecs decs = "[" ^ (String.concatWith (List.map (decs, dec2s), ", ")) ^ "]"
val toVerboseStringExp = exp2s
val toVerboseStringPat = pat2s
val toVerboseStringType = ty2s

fun verbosePrintDecs (decss: CoreML.Dec.t list vector) =  let
   val idx = ref 0
   fun decsToLayoutString (decs: CoreML.Dec.t list) =
       Layout.toString
           (Layout.align (List.map (decs, CoreML.Dec.layout)))
   fun decsToString (decs: CoreML.Dec.t list) = let
      val currIdx = !idx
      val _ = idx := currIdx + 1
      val idxStr = concat ["#", Int.toString currIdx]
   in
      (print o concat) ["Dec(", idxStr, ")=\n",
                        "\tLayout(", idxStr, ")=", decsToLayoutString decs, "\n",
                        "\tVerbose(", idxStr, ")=", toVerboseStringDecs decs, "\n",
                        "\n"]
   end
in
   Vector.foreach (decss, decsToString)
end

end
