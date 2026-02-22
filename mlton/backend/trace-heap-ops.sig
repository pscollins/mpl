(* Copyright (C) 2026 Patrick Lu.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature TRACE_HEAP_OPS_STRUCTS =
   sig
      include RSSA_TRANSFORM_STRUCTS
   end

signature TRACE_HEAP_OPS =
   sig
      include TRACE_HEAP_OPS_STRUCTS

      (* Given a `Program.t` and a predicate on `Statement.t`s, returns all of
      the statements that match the predicate. *)
      val filterStatements:
          (Program.t * (Statement.t -> bool)) ->
          Statement.t list

      (* TODO(pscollins): Fill in *)
      val transform: Program.t -> Program.t
   end
