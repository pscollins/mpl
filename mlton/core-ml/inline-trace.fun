(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor InlineTrace (S: INLINE_TRACE_STRUCTS): INLINE_TRACE =
struct

open S
open CoreML

fun inlineTrace {prog} =
   let
      val currStmt = ref 0
      fun expToTypeString (exp: Exp.t) =
         case Exp.node exp of
            Exp.App _ => "App"
          | Exp.Case _ => "Case"
          | Exp.Con _ => "Con"
          | Exp.Const _ => "Const"
          | Exp.EnterLeave _ => "EnterLeave"
          | Exp.Handle _ => "Handle"
          | Exp.Lambda _ => "Lambda"
          | Exp.Let _ => "Let"
          | Exp.List _ => "List"
          | Exp.PrimApp _ => "PrimApp"
          | Exp.Raise _ => "Raise"
          | Exp.Record _ => "Record"
          | Exp.Seq _ => "Seq"
          | Exp.Var _ => "Var"
          | Exp.Vector _ => "Vector"
      fun verbosePrintVbs vbs = let
         fun verbosePrintVb {exp, ...} =
             [expToTypeString exp, ","]
      in
         concat (List.concat (Vector.toList (Vector.map (vbs, verbosePrintVb))))
      end

      fun getUniqueLambdaFromVb {ctxt, exp, layPat, next, pat, regionPat} =
          case exp of
            |  Exp.Lambda l => SOME l
            | _ => NONE
      fun getUniqueLambdaFromVbs vbs =
          if Vector.length vbs = 1 then 
             getUniqueLambdaFromVb (Vector.first vbs)
          else NONE
      fun printIsNone opt =
          case opt of
            |  SOME _ => "SOME!"
            |  _ => "NONE"
      fun decTypeToString (dec: Dec.t) =
          case dec of
              Dec.Datatype _ => "Datatype"
            | Dec.Exception _ => "Exception"
            | Dec.Fun {decs, tyvars} =>
              concat ["Fun(#decs=", Int.toString (Vector.length decs),
                      ", #tyvars=", Int.toString (Vector.length (tyvars ())), ")"]
            | Dec.Val {rvbs, tyvars, vbs, ...} =>
              concat ["Val(#rvbs=", Int.toString (Vector.length rvbs),
                      ", #tyvars=", Int.toString (Vector.length (tyvars ())),
                      ", #vbs=", Int.toString (Vector.length vbs), ")=",
                      verbosePrintVbs vbs,
                      " match? ",
                      printIsNone (getUniqueLambdaFromVbs vbs)
                     ]
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
                 let
                    val _ = print (concat ["FUNC(", expToTypeString func, ")="])
                    val _ = Layout.outputl (Exp.layout func, Outstream0.standard)
                    val _ = print (concat ["ARG(", expToTypeString arg, ")="])
                    val _ = Layout.outputl (Exp.layout arg, Outstream0.standard)
                 in
                    Exp.App {func = doExp func,
                             arg = doExp arg,
                             inline = inline}
                 end
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
          val _ = print (concat ["Statement #",
                                 Int.toString currIdx,
                                 " (", decTypeToString dec, ")",
                                 "\n"])
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
