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

(* Special case for `UseDefGraph`, which wants to include the `base` of an
`Update` statement as a "def" *)
fun extractDefsForUseDefGraph (stmt: Statement.t) = let
   val prevDefs = ref (extractDefs stmt)
   val _ = case stmt of
               Statement.Update {base, ...} =>
               prevDefs := (VarSet.add (!prevDefs, Base.object base))
            |  _ =>  ()
in
   !prevDefs
end

fun fromProgram (program: Program.t): t = let
   val g as {graph, getNode, getVar} = new()
   val doAddEdge = addEdge g
   fun addEdges (froms: VarSet.t, tos: VarSet.t) = let
      fun addEdgesForSource (from: Var.t) = let
         fun addEdgeToSink (to: Var.t) =
             doAddEdge (from, to)
      in
         VarSet.foreach (tos, addEdgeToSink)
      end
   in
      VarSet.foreach (froms, addEdgesForSource)
   end
   fun addStatement (stmt: Statement.t) =
       addEdges (extractUses stmt, extractDefsForUseDefGraph stmt)
   fun addBlock (b: Block.t) = let
      (* TODO(pscollins): args, transfer *)
      val Block.T {statements, ...} = b
   in
       Vector.foreach (statements, addStatement)
   end
   fun addFunction (f: Function.t) =
       Vector.foreach (Function.blocks f, addBlock)
   fun addProgram (p: Program.t) = let
      val Program.T {functions, globals, ...} = p
      val _ = List.foreach (functions, addFunction)
      val _ = Vector.foreach (globals, addStatement)
   in
      ()
   end
in
   addProgram program; g
end

                                              
end
end
