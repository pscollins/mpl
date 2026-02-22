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

      (* Given a `Program.t` and a (partial) transformation on `Statement.t`s,
      returns a `Program.t` resulting from applying the transformation on every
      `Statement.t` in the `Program.t` and replacing for the non-`NONE` results. *)
      val mapStatements:
          (Program.t * (Statement.t -> Statement.t option)) ->
          Program.t

      (* TODO(pscollins): Fill in *)
      val transform: Program.t -> Program.t
   end
