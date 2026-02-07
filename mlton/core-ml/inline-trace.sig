(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature INLINE_TRACE_STRUCTS =
   sig
      structure CoreML: CORE_ML
   end

signature INLINE_TRACE =
   sig
      include INLINE_TRACE_STRUCTS

      val inlineTrace:
         {prog: CoreML.Dec.t list vector} ->
         {prog: CoreML.Dec.t list vector}
   end
