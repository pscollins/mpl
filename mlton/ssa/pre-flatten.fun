functor PreFlatten (S: SSA_TRANSFORM_STRUCTS): PRE_FLATTEN =
struct
open S

type walker = {
   (* Hook to execute before visiting a function body *)
   beforeFunc: Function.t -> unit,
   (* Hook to execute after visiting a function body *)
   afterFunc: Function.t -> unit,
   (* Hook to execute before visiting a block body *)
   beforeBlock: Block.t -> unit,
   (* Hook to execute after visiting a block body *)
   afterBlock: Block.t -> unit,
   (* Hook to execute when visiting a statement *)
   statement: Statement.t -> unit
}

fun doWalk (w: walker, p: Program.t) = let 
   val {beforeFunc, afterFunc, beforeBlock, afterBlock, statement}
       = w
   val Program.T {globals, ...} = p
   fun noop() = ()
   fun doWalkBlock (b: Block.t) = let
      val _ = beforeBlock b
      val _ = Vector.foreach (Block.statements b, statement)
      val _ = afterBlock b
   in
      noop
   end
   fun doWalkFunc (f: Function.t) = let
      val _ = beforeFunc f
      val _ = Function.dfs (f, doWalkBlock)
      val _ = afterFunc f
   in
      noop
   end
in
   Vector.foreach (globals, statement);
   Program.dfs (p, doWalkFunc)
end

fun transform (p: Program.t): Program.t =
    p
end
