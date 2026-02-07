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
      val _ =
         Vector.foreachi (prog, fn (i, decs) =>
            (print (concat ["Vector entry: ", Int.toString i, "\n"]);
             List.foreachi (decs, fn (j, dec) =>
                (print (concat ["Statement #", Int.toString j, "\n"]);
                 Layout.outputl (Dec.layout dec, Outstream0.standard)))))
   in
      {prog = prog}
   end

end