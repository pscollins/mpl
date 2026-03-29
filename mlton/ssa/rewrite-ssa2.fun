functor RewriteSsa2 (S: SSA_TREE2): REWRITE_SSA2 =
struct
structure Ssa2 = S

open Ssa2

structure VarSet = UnorderedSet (Var)

fun doExtract (stmt: Statement.t,
               walk: (Statement.t * (Var.t -> unit)) -> unit): VarSet.t = let
   val acc = ref (VarSet.empty)
   fun collectVar (v: Var.t) = let
      val acc' = VarSet.add (!acc, v)
      val _ = acc := acc'
   in
      ()
   end
   val _ = walk (stmt, collectVar)
in
   !acc
end

fun extractUses (stmt: Statement.t): VarSet.t =
    doExtract (stmt, Statement.foreachUse)

fun extractDefs (stmt: Statement.t): VarSet.t = let
   fun extractVar (v: Var.t, _: Type.t): Var.t = v
   fun forEachDefVarOnly (s: Statement.t, f: Var.t -> unit) =
       Statement.foreachDef (s, f o extractVar)
in
   doExtract (stmt, forEachDefVarOnly)
end


fun getDefIndex (stmts: Statement.t vector, v: Var.t): int option = let
   fun isMatch (s: Statement.t): bool =
      VarSet.contains (extractDefs s, v)
in
   Vector.index (stmts, isMatch)
end

structure UseDefGraph = struct
structure G = DirectedGraph
type graph = Var.t G.t
type t = {
   graph: graph,
   getNode: Var.t -> Var.t G.Node.t,
   getVar: Var.t G.Node.t -> Var.t
}

fun new () = let
   val graph: graph = G.new ()
   val {get = getVar, set = setVar, ...} =
       Property.getSetOnce (G.Node.plist,
                            Property.initRaise ("useDefGraph", G.Node.layout))
   fun makeNode (v: Var.t) = let
      val node = G.newNode graph
      val _ = setVar (node, v)
   in
      node
   end
   val {get = getNode, ...} =
       Property.get (Var.plist, Property.initFun makeNode)
in
   {graph = graph,
    getNode = getNode,
    getVar = getVar}
end

fun addEdge (g: t) (u: Var.t, v: Var.t): unit = let
   val {graph, getNode, ...} = g
   val u' = getNode u
   val v' = getNode v
   fun doAdd (from, to) =
       G.addEdge (graph, {from=from, to=to})
   val _ = doAdd (u', v')
   val _ = doAdd (v', u')
in
   ()
end

fun findReachable ({graph,  getNode, getVar}: t, root: Var.t) = let
   val seen = ref (VarSet.empty)
   fun markSeen (n: Var.t G.Node.t): unit = let
      val seen' = VarSet.add (!seen, getVar n)
   in
      seen := seen'
   end
   val _ = G.foreachDescendent (graph, getNode root, markSeen)
in
   !seen
end

end
end
