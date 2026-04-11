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

datatype argChoice =
            Preserve
          | FlattenTuple

fun buildFlattenedFunction (f: Function.t, choices: argChoice vector) = let
   val needBinds: (bind list) ref = ref []
   fun addBind (bind) = let
      val newBinds = bind::(!needBinds)
   in
      needBinds := newBinds
   end
   fun extractVar (var, ty) = var
  (* Adds the 'reverse binding' `typleVar = tuple(flattendVars)`
     to `needBinds` and returns `flattendVars` *)
   fun addFlattenedBind (tupleVar, flattenedVars) = let
      val bind = BindTuple {to = tupleVar,
                            froms = Vector.map (flattenedVars, extractVar)}
      val _ = addBind bind
   in
      flattenedVars
   end
   fun doFlatten typedVar =
       case flattenTupleVar typedVar of
           SOME flattenedVars => addFlattenedBind (typedVar, flattenedVars)
         | NONE => Error.bug "Tried to flatten non-tuple type!"
   fun applyChoice (typedVar, choice): typedVar vector =
       case choice of
           Preserve => Vector.new1 typedVar
         | FlattenTuple => doFlatten typedVar
   val {args, blocks, inline, name, raises, returns, start} =
       Function.dest f
   val newArgs = Vector.concatV (Vector.map2 (args, choices, applyChoice))
   fun buildNewFunc binds = let
      val newBlock = buildBindBlock (Vector.fromList binds, start)
   in
      Function.new {args = newArgs,
                    blocks = Vector.concat [Vector.new1 newBlock, blocks],
                    inline = inline,
                    name = name,
                    raises = raises,
                    returns = returns,
                    start = Block.label newBlock}
   end
in
   case !needBinds of
       [] => Error.bug "No-op flattening decision"
    | binds => buildNewFunc binds
end

datatype varChoice =
         PreserveVar
         | FlattenTupleVar of Var.t vector

type varChoiceManager = {
   getVarChoiceProp: Var.t -> varChoice,
   setVarChoiceProp: Var.t * varChoice -> unit,
   destroyVarChoiceProps: unit -> unit
}

fun newVarChoiceManager () = let
   (* TODO(pscollins): Consider making "missing" into an error *)
   val {get, set, destroy} = Property.destGetSetOnce (Var.plist,
                                                      Property.initConst PreserveVar)
in
   {getVarChoiceProp = get,
    setVarChoiceProp = set,
    destroyVarChoiceProps = destroy}
end

fun chooseVarsInStatement (vt: varChoiceManager, s: Statement.t) = let
   val {setVarChoiceProp, ...} = vt
   val Statement.T {exp, ty, var=maybeVar} = s
   fun getDecisionFromParents (parents: Var.t vector) =
       (* `unit` is represented by an empty tuple that we don't want to flatten
       through *)
       if Vector.isEmpty parents then
          PreserveVar
       else
          FlattenTupleVar parents
in
   case (exp, maybeVar) of
       (Exp.Tuple parents, SOME var) =>
       setVarChoiceProp (var, getDecisionFromParents parents)
    | _ => ()
end

fun getVarChoice (vt: varChoiceManager, v: Var.t) = let
   val {getVarChoiceProp, ...} = vt
in
   getVarChoiceProp v
end

fun destroyVarChoiceManager (vt: varChoiceManager) = let
   val {destroyVarChoiceProps, ...} = vt
in
   destroyVarChoiceProps()
end

fun transform (p: Program.t): Program.t =
    p
end
