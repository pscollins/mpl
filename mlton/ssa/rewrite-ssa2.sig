signature REWRITE_SSA2 =
sig
   structure Ssa2: SSA_TREE2
   include SSA_TREE2

   structure VarSet: SET where type Element.t = Var.t

  (* This file contains ad-hoc rewrite passes for SSA2, intended primarily for
  debugging *)

 (* Internal utilities for the rewrite passes (exposed for testing) *)

  (*  *)

   (* Returns a set of all `Var.t`s used by this statement *)
   val extractUses: Statement.t -> VarSet.t

   (* Returns a set of all `Var.t`s defined by this statement *)
   val extractDefs: Statement.t -> VarSet.t

   (* If `Var.t` is defined by some statement in the provided `Statement.t
   vector`, returns it. The SSA property guarantees that in this case, the index
    is unique. Otherwise, returns NONE. *)
   val getDefIndex: (Statement.t vector * Var.t) -> int option


   (* *)
   (* Executes the following steps: *)

   (*   1. Finds the `Statement.t` that defines the given `Var.t`, if any *)
   (*   2. Recursively walks down the use-def chain that begins at that statement *)

   (* returning an empty list if no such statement exists. *)
   (* *)
   (* val getDependenciesDownwards: *)
   (*     (Statement.t vector * Var.t) -> Statement.t list *)

   (* An (undirected) edge whose nodes are `Var.t`s, where `u` and `v` are
   connected by an edge if `u` is a `Var.t` that appears on the RHS of the
   definition of `v` (or vice-versa) *)
   structure UseDefGraph = struct
   structure G = DirectedGraph
     type graph = Var.t G.t
     type t = {
        (* Underlying digraph *)
        graph: graph,
        (* Accessors to map from `Var.t`s to graph nodes (and vice-versa) *)
        getNode: Var.t -> G.Node.t,
        getVar: G.Node.t -> Var.t
     }
     (* Constructs a new (empty) graph *)
     val new: unit -> t
     (* Adds a new (undirected) edge to the graph *)
     (* val addEdge: t -> (Var.t * Var.t) -> unit *)
   end

  (* Rewrite passes defined below *)

  (* TODO(pscolins): Add rewrites *)
end
