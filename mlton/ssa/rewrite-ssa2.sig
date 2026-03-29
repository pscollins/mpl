signature REWRITE_SSA2 =
sig
   structure Ssa2: SSA_TREE2
   include SSA_TREE2

   structure VarSet: SET where type Element.t = Var.t

  (* This file contains ad-hoc rewrite passes for SSA2, intended primarily for
  debugging *)

 (* Internal utilities for the rewrite passes (exposed for testing) *)

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
   definition of `v` (or vice-versa).

   It is intended to be defined such that the subgraph reachable from `v` is the
   smallest possible subgraph that contains all `Var.t`s "relevant to" `v`, so
   that we can prune a `Program.t` to only contain these `Var.t`s without
   "losing" information.
    *)
   structure UseDefGraph: sig
     type graph
     type t = {
        (* Underlying digraph *)
        graph: graph,
        (* Accessors to map from `Var.t`s to graph nodes (and vice-versa) *)
        getNode: Var.t -> Var.t DirectedGraph.Node.t,
        getVar: Var.t DirectedGraph.Node.t -> Var.t
     }
     (* Constructs a new (empty) graph *)
     val new: unit -> t
     (* Adds a new (undirected) edge to the graph *)
     val addEdge: t -> (Var.t * Var.t) -> unit
     (* Finds all of the `Var.t`s reachable from the provided `Var.t` *)
     val findReachable: (t * Var.t) -> VarSet.t

     (* Constructs a UseDefGraph from the provided `Program.t` according to the
     following rules.

     Let `n1`, `n2` be vertices in the graph corresponding to `Var.t`s `v1`,
     `v2`, respectively. Then there is an edge between `n1` and `n2` (and back)
     if:

     * `v1` is connected to `v2` by a `Statement.t`, e.g.:

       * `v1` is the `var` of a `Bind` expression whose `exp` contains `v2`
       * `v1` is the `base` of an `Update` epxression whose `value` is `v2`

     * `v1` is connected to `v2` by an "argument" relationship, e.g.:

       * A function defined as `fun f(v1)` is called as `f(v2)`
       * A block with formal parameter `v1` is called with argument `v2`

     * `v1` is connected to `v2` by a "return" relationship, e.g.:

       * `v1` is marked the argument to a `Transfer.Return`, and `v2` is an
         argument to the `Block.t` that corresponds to the `cont` argument of
         the `Return.t` for some `Transfer.Call`.
     *)
     val fromProgram: Program.t -> t
   end

   (* Given a collection of "watched variables" and a `Program.t`, deletes every
   `Statement.t` in the `Program.t` that does not refer to any `Var.t` in the
   collection. *)
   val trimProgram: (Program.t * VarSet.t) -> Program.t

  (* Rewrite passes defined below *)

  (* TODO(pscolins): Add rewrites *)
end
