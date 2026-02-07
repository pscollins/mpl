(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor AnnotateTrace (S: ANNOTATE_TRACE_STRUCTS): ANNOTATE_TRACE =
struct

open S
open CoreML

fun annotateTrace {prog} =
   let
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
         fun doExpNode (expNode: Exp.node): Exp.node =
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
               | Exp.Con _ => expNode (* constructor can't contain PrimApp *)
               | Exp.Const _ => expNode     (* const can't contain PrimAPp *)
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
               | Exp.PrimApp primApp => Exp.PrimApp (doPrimApp primApp)
               | Exp.Raise exp => Exp.Raise (doExp exp)
               | Exp.Record elts => Exp.Record (Record.map (elts, doExp))
               | Exp.Seq exps => Exp.Seq (Vector.map (exps, doExp))
               | Exp.Var _ => expNode (* no PrimApp *)
               | Exp.Vector exps => Exp.Vector (Vector.map (exps, doExp))
               |  _ => expNode
               (* | Case {ctxt, kind, nest, matchDiags, noMatch, region, rules, test}  => *)
               (*   expNode  *)
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
      and doDec (dec: Dec.t): Dec.t = let
          val currIdx =  !currStmt
          val _ = currStmt := (currIdx + 1)
          val _ = print (concat ["Statement #", Int.toString currIdx, "\n"])
          val _ = Layout.outputl (Dec.layout dec, Outstream0.standard)
      in
         case dec of
             Dec.Val {matchDiags, rvbs, tyvars, vbs} =>
             Dec.Val {matchDiags = matchDiags,
                      rvbs = doRvbs rvbs,
                      tyvars = tyvars,
                      vbs = doVbs vbs}
           | Dec.Fun funDec => Dec.Fun (doFun funDec)
           | Dec.Datatype _ => dec  (* no PrimApps *)
           | Dec.Exception _ => dec (* no PrimApps *)
      end
      and doPrimApp (primApp as {args: Exp.t vector, prim: Type.t Prim.t,
                                 targs: Type.t vector}) = let
         fun emitStaticSourceMark () = let
            val _  = print "PRINTING PRIM APP ARGS!\n"
            val _ = Layout.outputl (Layout.tuple (Vector.toListMap (args, Exp.layout)),
                                    Outstream0.standard)
         in
            Prim.Trace_sourceMark
         end
      in
         case prim of
             Prim.Trace_sourceMark => {args = args, prim = emitStaticSourceMark(),
                                       targs = targs}
           |  _ => primApp
      end
      fun doDecs (decs: Dec.t list): Dec.t list =
          List.map (decs, doDec)
   in
      {prog = Vector.map (prog, doDecs)}
   end

end
