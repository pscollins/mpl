(* Copyright (C) 2026 Patrick.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature PARSE_SSA2 =
   sig
      structure Ssa: SSA_TREE2
      val parseString: string -> Ssa.Program.t
   end
