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
   fun extractVar (v: Var.t, t: Type.t): Var.t = v
   fun forEachDefVarOnly (s: Statement.t, f: Var.t -> unit) =
       Statement.foreachDef (s, f o extractVar)
in
   doExtract (stmt, forEachDefVarOnly)
end


fun getDefIndex (stmts: Statement.t vector, v: Var.t): int option = let
   fun isMatch (s: Statement.t): bool = let
      val vars = extractDefs s
   in
      VarSet.contains (extractDefs s, v)
   end
in
   Vector.index (stmts, isMatch)
end

structure UseDefGraph = struct 

fun new () = let 
   val graph: graph = G.new ()
   fun {get = getVar, set = setVar} =
       Property.getSetOnce (G.Node.plist,
                            Property.initRaise ("useDefGraph", G.Node.layout))
   fun mkNode (v: Var.t): Var.t G.Node.t = let
      val node = G.newNode graph
      val _ = setVar (node, v)
   in
      node
   end
   val {get = getNode, ...} =
       Property.get (Var.plist, Property.initFun newNode)
in
   {graph = graph,
    getNode = getNode,
    getVar = getVar}
end

(* fun getDependenciesDownwards *)
(*         (stmts: Statement.t vector, v: Var.t): Statement.t list = let *)
(*    val wantVars = ref (VarSet.singleton v) *)

(*    fun processStmt (s: Statement.t, wantVars: Var *)
(*    fun getDependenciesIn (stmts: Statement.t vector, *)
(*                           wantVars: VarSet.t) *)

                         

end
