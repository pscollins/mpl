(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor CoreMLUtil (S: CORE_ML_UTIL_STRUCTS): CORE_ML_UTIL =
struct

open S
open CoreML

fun decId (decs: Dec.t list): Dec.t list = decs

end
