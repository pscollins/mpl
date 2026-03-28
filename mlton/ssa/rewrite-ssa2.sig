signature REWRITE_SSA2 =
sig
   structure Ssa2: SSA_TREE2
   include SSA_TREE2

   structure VarSet: SET where type Element.t = Var.t

  (* This file contains ad-hoc rewrite passes for SSA2, intended primarily for
  debugging *)

 (* Internal utilities for the rewrite passes (exposed for testing) *)

  (*  *)

   (* Returns a set of all `Var.t`s defined by this statement *)
   val extractUses: Statement.t -> VarSet.t

   (* Returns a set of all `Var.t`s used by this statement *)
   val extractDefs: Statement.t -> VarSet.t


   (* If `Var.t` is defined by some statement in the provided `Statement.t
   vector`, returns it. The SSA property guarantees that in this case, the index
    is unique. Otherwise, returns NONE. *)
   val getDefIndex: (Statement.t vector * Var.t) -> int option

  (* val getDependencyGraphDownward: (Block.t * Var.t) -> *)
  (*                                 Statement.t list *)

  (* val extractSubgraphDownward: (Block.t * Var.t) -> *)
  (*                              Statement.t list *)
                              
  (* Rewrite passes defined below *)

  (* TODO(pscolins): Add rewrites *)
end
