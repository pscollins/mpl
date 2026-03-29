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


fun vectorToSet (vs: Var.t vector): VarSet.t = let
   fun doAdd (v: Var.t, varSet: VarSet.t) =
       VarSet.add (varSet, v)
in
   Vector.fold (vs, VarSet.empty, doAdd)
end

(* Returns a mapping from `Func.t` (i.e. labels) to `Function.t` objects *)
fun buildFuncMapping (p: Program.t): (Func.t -> Function.t) = let
   val Program.T {functions, ...} = p
   val {get = getFunction, set = setFunction, ...} =
       Property.getSetOnce
           (Func.plist, Property.initRaise ("function lookup", Func.layout))
   fun addFunc f =
       setFunction (Function.name f, f)
   val _ = List.foreach (functions, addFunc)
in
   getFunction
end

(* Like above, but for block labels -> blocks *)
fun buildLabelMapping (p: Program.t): (Label.t -> Block.t) = let
   val Program.T {functions, ...} = p
   val {get = getBlock, set = setBlock, ...} =
       Property.getSetOnce
           (Label.plist, Property.initRaise ("label lookup", Label.layout))
   fun addBlock b = setBlock (Block.label b, b)
   fun addFunction f = Vector.foreach (Function.blocks f, addBlock)
   val _ = List.foreach (functions, addFunction)
in
   getBlock
end

(* Builds a mapping from function labels to all possible return values *)
fun buildReturnMapping (p: Program.t): (Func.t -> VarSet.t) = let
   val Program.T {functions, ...} = p
   val {get = getReturns, set = setReturns, ...} =
       Property.getSetOnce
           (Func.plist, Property.initRaise ("return lookup", Func.layout))
   fun extractBlockReturns (b: Block.t): VarSet.t = let
      val Block.T {transfer, ...} = b
   in
      case transfer of
          Transfer.Return rets => vectorToSet rets
        | _ => VarSet.empty
   end
   fun addBlockReturns (b: Block.t, vs: VarSet.t): VarSet.t =
       VarSet.union (vs, extractBlockReturns b)
   fun extractFuncReturns (f: Function.t) =
       Vector.fold (Function.blocks f, VarSet.empty, addBlockReturns)
   fun addFunc f =
       setReturns (Function.name f, extractFuncReturns f)
   val _ = List.foreach (functions, addFunc)
in
   getReturns
end

local
   fun argsToSet (args: (Var.t * Type.t) vector): VarSet.t = let
      fun addArg (a: Var.t * Type.t, vs: VarSet.t): VarSet.t = let
         val (var, _) = a
      in
         VarSet.add (vs, var)
      end
   in
      Vector.fold (args, VarSet.empty, addArg)
   end
in
(* Extracts the arguments of `f` as a `VarSet.t` *)
fun getFuncArgs (f: Function.t): VarSet.t = let
   val {args, ...} = Function.dest f 
in
   argsToSet args
end

(* Extracts the arguments of `b` as a `VarSet.t` *)
fun getBlockArgs (b: Block.t): VarSet.t = let
   val Block.T {args, ...} = b
in
   argsToSet args
end
end

(* Returns the set of variables "used" by a `Transfer.t` *)
fun getTransferUses (transfer: Transfer.t): VarSet.t =
    (* TODO(pscollins): Handle the other cases *)
    case transfer of
        Transfer.Call {args, ...} => vectorToSet args
     |  Transfer.Goto {args, ...} => vectorToSet args
     |  _ => VarSet.empty

(* Returns the set of variables "defined" by `Transfer.t` (considiering
call-arguments as "definitons," since a call binds the arguments to the formal
paramters) *)
fun getTransferDefs
        (funcToFunction: Func.t -> Function.t,
         labelToBlock: Label.t -> Block.t,
         transfer: Transfer.t): VarSet.t =
    case transfer of
        Transfer.Call {func, ...} =>
        getFuncArgs (funcToFunction func)
     | Transfer.Goto {dst, ...} =>
        getBlockArgs (labelToBlock dst)
     (* TODO(pscollins): Handle the other cases *)
     |  _ => VarSet.empty

(* Special handling for the data dependency edges between return values and
function calls *)
fun getCallEdges (funcToReturns: Func.t -> VarSet.t,
                  labelToBlock: Label.t -> Block.t,
                  transfer: Transfer.t): (VarSet.t * VarSet.t) =
    case transfer of
        Transfer.Call {func, return = Return.NonTail {cont, ...}, ...} =>
        (funcToReturns func, getBlockArgs (labelToBlock cont))
        | _  => (VarSet.empty, VarSet.empty)

fun fromProgram (program: Program.t): t = let
   val g as {graph, getNode, getVar} = new()
   val doAddEdge = addEdge g
   val funcToFunction = buildFuncMapping program
   val funcToReturns = buildReturnMapping program
   val labelToBlock = buildLabelMapping program
   fun getTransferUseDefs (t: Transfer.t) =
       (getTransferUses t, getTransferDefs (funcToFunction,
                                            labelToBlock,
                                            t))
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
      val Block.T {statements, transfer, ...} = b
   in
      (* Add bindings for each statement *)
      Vector.foreach (statements, addStatement);
      (* Add bindings for the transfer out of this block *)
      addEdges (getTransferUseDefs transfer);
      (* Special case to handle dataflow through function returns *)
      addEdges (getCallEdges (funcToReturns, labelToBlock, transfer))
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

fun trimProgram (p: Program.t, wantVars: VarSet.t): Program.t = let
   val Program.T {datatypes, functions, globals, main} = p
   fun keepStmt (s: Statement.t) = let
      val sVars = VarSet.union (extractUses s, extractDefs s)
   in
      (not o VarSet.areDisjoint) (sVars, wantVars)
   end
   fun filterStmts (ss: Statement.t vector): Statement.t vector =
       Vector.keepAll (ss, keepStmt)
   fun filterArgs (args: (Var.t * Type.t) vector) = let
      fun keepArg (v, _) = VarSet.contains (wantVars, v)
   in
      Vector.keepAll (args, keepArg)
   end
   fun filterBlock (b: Block.t) = let
      val Block.T {args, label, statements, transfer} = b
   in
      Block.T {args = filterArgs args,
               label = label,
               statements = filterStmts statements,
               transfer = transfer}
   end
   fun filterFunction (f: Function.t) = let
      val {args, blocks, inline, name, raises, returns, start} =
          Function.dest f
   in
      Function.new {args = filterArgs args,
                    blocks = Vector.map (blocks, filterBlock),
                    inline = inline,
                    name = name,
                    raises = raises,
                    returns = returns,
                    start= start}
   end
in
   Program.T {datatypes = datatypes,
              functions = List.map (functions, filterFunction),
              globals = filterStmts globals,
              main = main}
end

fun isolateSubgraph (p: Program.t, v: Var.t): Program.t = let
   val graph = UseDefGraph.fromProgram p
   val vars = UseDefGraph.findReachable (graph, v)
in
   trimProgram (p, vars)
end

end
