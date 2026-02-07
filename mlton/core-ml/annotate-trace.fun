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
      fun doLambda l =
         let
            val {arg, argType, body, inline} = Lambda.dest l
         in
            Lambda.make {arg = arg, argType = argType, body = body, inline = inline}
         end
      fun doVbs x = x
      fun doRvbs rvbs = let
         fun doRvb {lambda, var} =
             {lambda = doLambda lambda, var = var}
      in
         Vector.map (rvbs, doRvb)
      end
      fun doDec (dec: Dec.t): Dec.t = let
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
          | _ => dec
      end
      fun doDecs (decs: Dec.t list): Dec.t list =
          List.map (decs, doDec)
   in
      {prog = Vector.map (prog, doDecs)}
   end

end
