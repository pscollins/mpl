(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature ANNOTATE_TRACE_STRUCTS =
   sig
      structure CoreML: CORE_ML
   end

signature ANNOTATE_TRACE =
   sig
      include ANNOTATE_TRACE_STRUCTS

      val annotateTrace:
         {prog: CoreML.Dec.t list vector} ->
         {prog: CoreML.Dec.t list vector}
   end
