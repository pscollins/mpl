signature REWRITE_SSA2 =
sig
   structure Ssa2: SSA_TREE2
   include SSA_TREE2

  (* This file contains ad-hoc rewrite passes for SSA2, intended primarily for
  debugging *)

 (* Internal utilities for the rewrite passes (exposed for testing) *)

  (*  *)

  (* val extractUses: Statement.t -> Var.t list *)

  (* val extractDefs: Statement.t -> Var.t list *)


  (* val getDependencyGraphDownward: (Block.t * Var.t) -> *)
  (*                                 Statement.t list *)

  (* val extractSubgraphDownward: (Block.t * Var.t) -> *)
  (*                              Statement.t list *)
                              
  (* Rewrite passes defined below *)

  (* TODO(pscolins): Add rewrites *)
end
