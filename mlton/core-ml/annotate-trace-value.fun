(* Copyright (C) 2025 MLton.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor AnnotateTraceValue (S: ANNOTATE_TRACE_VALUE_STRUCTS): ANNOTATE_TRACE_VALUE =
struct

open S
open CoreML

fun annotateTraceValue {prog} = {prog = prog}

end
