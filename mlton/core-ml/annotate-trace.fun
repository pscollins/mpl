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
      val counter = ref 0
      val _ =
         Vector.foreach (prog, fn decs =>
            List.foreach (decs, fn _ =>
               (print (concat ["Statement ", Int.toString (!counter), "\n"]);
                counter := !counter + 1)))
   in
      {prog = prog}
   end

end