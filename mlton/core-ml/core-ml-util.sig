(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature CORE_ML_UTIL_STRUCTS =
   sig
      structure CoreML: CORE_ML
   end

signature CORE_ML_UTIL =
   sig
      include CORE_ML_UTIL_STRUCTS

      val decId: CoreML.Dec.t list -> CoreML.Dec.t list
   end
