functor FlattenUtil (S: SSA_TRANSFORM_STRUCTS): FLATTEN_UTIL =
struct
open S

(* Applies an effectful expression to each `Function.t` in `p` *)
fun foreachFunction (p: Program.t, funcF: (Function.t -> unit)): unit = let
   val Program.T {functions, ...} = p
in
   List.foreach (functions, funcF)
end

(* Manages Func.t -> Function + Label.t -> Block mappings *)
type funcsMap = {
   getFunc: Func.t -> Function.t,
   getBlock: Label.t -> Block.t,
   getCallees: Func.t -> Func.t vector,
   destroyFuncsMap: unit -> unit
}

fun newFuncsMap (p: Program.t): funcsMap = let
   val {get=getFunc, set=setFunc, destroy=destroyFuncsMapFuncs} =
       Property.destGetSetOnce (Func.plist,
                                Property.initRaise ("function lookup", Func.layout))

   val {get=getBlock, set=setBlock, destroy=destroyFuncsMapBlocks} =
       Property.destGetSetOnce (Label.plist,
                                Property.initRaise ("block lookup", Label.layout))
   fun destroyFuncsMap() = let
      val _ = destroyFuncsMapFuncs()
      val _ = destroyFuncsMapBlocks()
   in
      ()
   end

   fun getCallees func = Error.unimplemented "TODO"

   fun addBlockToMapping (b: Block.t) = setBlock (Block.label b, b)
   fun addFuncToMapping (f: Function.t) = let
      val _ = Vector.foreach (Function.blocks f, addBlockToMapping)
   in
      setFunc (Function.name f, f)
   end
   (* Use foreachFunction rather than `walker` because the DFS traversal pattern
      doesn't reach disconnected functions, and so a program containing any such
      function hits the `initRaise` above. The ordering of our `addFuncToMapping`
      calls doesn't matter, so we might as well avoid the error by just setting up
      the mapping for all functions. *)
   val _ = foreachFunction (p, addFuncToMapping)
in
   {getFunc = getFunc, getBlock = getBlock, destroyFuncsMap = destroyFuncsMap}
end
end
