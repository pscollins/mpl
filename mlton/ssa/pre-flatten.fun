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

type typedVar = Var.t * Type.t
fun flattenTupleVar (var, ty): (typedVar vector) option = let
   fun buildVar (t: Type.t): typedVar = (Var.newString "flattened", t)
   fun buildVars (ts: Type.t vector): typedVar vector =
       Vector.map (ts, buildVar)
in
   Option.map (Type.deTupleOpt ty, buildVars)
end


datatype bind = BindTuple of {to: typedVar, froms: Var.t vector}

fun buildBindBlock (binds: bind vector, goto: Label.t): Block.t = let
   fun mkStmt (bind): Statement.t =
       case bind of
           BindTuple {to=(toVar, toType), froms=froms} =>
           Statement.T {exp = Exp.Tuple froms,
                        ty = toType,
                        var = SOME toVar}

   (* We'll rely on the fact that the first block in a function can't have
      args  *)
   val gotoTransfer = Transfer.Goto {args = Vector.new0(), dst = goto}
in
   Block.T {args = Vector.new0(),
            label = Label.newString "forBind",
            statements = Vector.map (binds, mkStmt),
            transfer = gotoTransfer}
end


fun transform (p: Program.t): Program.t =
    p
end
