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

val defaultWalker: walker = let
   fun noop (x: 'a) = ()
   (* Work around type system restriction *)
   val noopF: Function.t -> unit = noop
   val noopB: Block.t -> unit = noop
   val noopS: Statement.t -> unit = noop
in
   {beforeFunc = noopF,
    afterFunc = noopF,
    beforeBlock = noopB,
    afterBlock = noopB,
    statement = noopS}
end

fun statementWalker (statementF: Statement.t -> unit): walker = let
   val {beforeFunc, afterFunc, beforeBlock, afterBlock,
        ...} = defaultWalker
in
   {beforeFunc = beforeFunc,
    afterFunc = afterFunc,
    beforeBlock = beforeBlock,
    afterBlock = afterBlock,
    statement = statementF}
end

fun beforeFunctionWalker (beforeFunc: Function.t -> unit): walker = let
   val {afterFunc, beforeBlock, afterBlock, statement, ...} = defaultWalker
in
   {beforeFunc = beforeFunc,
    afterFunc = afterFunc,
    beforeBlock = beforeBlock,
    afterBlock = afterBlock,
    statement = statement}
end


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

(* If `blockF` returns SOME for any `Block.t` in the `Function.t`, rewrites
   the `Function.t` to point to the modified block list. Otherwise, returns the
   original `Function.t` *)
fun mapBlocks (p: Program.t, blockF: (Block.t -> Block.t option)) = let
   val Program.T {datatypes, functions, globals, main} = p
   fun doFunc (f: Function.t) = let
      val oldBlocks = Function.blocks f
      val maybeNewBlocks = Vector.map (oldBlocks, blockF)
      val allNone = Vector.forall (maybeNewBlocks, Option.isNone)
      fun buildNewF() = let
         fun selectBlock (oldBlock: Block.t, maybeNewBlock: Block.t option) =
             case maybeNewBlock of
                 SOME newBlock => newBlock
               | NONE => oldBlock
         val {args, inline, name, raises, returns, start, ...} =
             Function.dest f
      in
         Function.new {
            args = args,
            blocks = Vector.map2 (oldBlocks, maybeNewBlocks, selectBlock),
            inline = inline,
            name = name,
            raises = raises,
            returns = returns,
            start = start
         }
      end
   in
      if allNone then f
      else buildNewF()
   end
in
   Program.T {datatypes = datatypes,
              functions = List.map (functions, doFunc),
              globals = globals,
              main = main}
end

(* Applies an effectful expression to each `Function.t` in `p` *)
fun foreachFunction (p: Program.t, funcF: (Function.t -> unit)): unit = let
   val Program.T {functions, ...} = p
in
   List.foreach (functions, funcF)
end

(* Applies an effectful expression to each `Statment.t` in `p` *)
fun foreachStatement (p: Program.t, statementF: (Statement.t -> unit)): unit = let
   fun doBlock b = Vector.foreach (Block.statements b, statementF)
   fun doFunc f = Vector.foreach (Function.blocks f, doBlock)
in
   foreachFunction (p, doFunc)
end


(* Manages Func.t -> Function + Label.t -> Block mappings *)
type funcsMap = {
   getFunc: Func.t -> Function.t,
   getBlock: Label.t -> Block.t,
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

type typedVar = Var.t * Type.t

fun flattenTupleVar (var, ty): (typedVar vector) option = let
   fun buildVar (t: Type.t): typedVar = (Var.newString "flattenedVar", t)
   fun buildVars (ts: Type.t vector): typedVar vector =
       Vector.map (ts, buildVar)
in
   Option.map (Type.deTupleOpt ty, buildVars)
end

fun flattenConVar ((var, ty), argTys): (typedVar vector) option = let
   fun buildVar (t: Type.t): typedVar = (Var.newString "flattenedCon", t)
in
   case Type.dest ty of
       (* TODO: more validation? *)
       Type.Datatype _ =>
       SOME (Vector.map (argTys, buildVar))
     | _ => NONE
end


datatype bind = BindTuple of {to: typedVar, froms: Var.t vector}
              | BindCon of {to: typedVar, froms: Var.t vector, con: Con.t}

fun buildBindBlock (binds: bind vector, goto: Label.t): Block.t = let
   fun mkStmt (bind): Statement.t =
       case bind of
           BindTuple {to=(toVar, toType), froms=froms} =>
           Statement.T {exp = Exp.Tuple froms,
                        ty = toType,
                        var = SOME toVar}
        | BindCon {to=(toVar, toType), froms, con} =>
           Statement.T {exp = Exp.ConApp {args=froms, con=con},
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
          | FlattenCon of {argTys: Type.t vector, con: Con.t}

fun newFuncNamedLike (name: Func.t, suffix) = let
   val currName = Func.toString name
in
   Func.newString (concat [currName, "_", suffix])
end

fun buildFlattenedFunction (f: Function.t, choices: argChoice vector) = let
   val needBinds: (bind list) ref = ref []
   fun addBind (bind) =
      List.push (needBinds, bind)
   fun extractVar (var, ty) = var
  (* Adds the 'reverse binding' `tupleVar = tuple(flattendVars)`
     to `needBinds` and returns `flattendVars` *)
   fun addFlattenedTupleBind (tupleVar, flattenedVars) = let
      val bind = BindTuple {to = tupleVar,
                            froms = Vector.map (flattenedVars, extractVar)}
      val _ = addBind bind
   in
      flattenedVars
   end
   (* Adds the 'reverse binding' `conVar = con (flattendVars)`
     to `needBinds` and returns `flattendVars` *)
   fun addFlattenedConBind (conVar, con, flattenedVars) = let
      val bind = BindCon {to = conVar,
                          froms = Vector.map (flattenedVars, extractVar),
                          con = con}
      val _ = addBind bind
   in
      flattenedVars
   end

   fun doFlattenTuple typedVar =
       case flattenTupleVar typedVar of
           SOME flattenedVars => addFlattenedTupleBind (typedVar, flattenedVars)
         | NONE => Error.bug "Tried to flatten non-tuple type!"
   fun doFlattenCon (typedVar: typedVar, {argTys: Type.t vector,
                                          con: Con.t}) =
       case flattenConVar (typedVar, argTys) of
           SOME flattenedVars => addFlattenedConBind (typedVar, con,
                                                      flattenedVars)
         | NONE => Error.bug "Tried to flaten non-con type!"
   fun applyChoice (typedVar, choice): typedVar vector =
       case choice of
           Preserve => Vector.new1 typedVar
         | FlattenTuple => doFlattenTuple typedVar
         | FlattenCon conInfo => doFlattenCon (typedVar, conInfo)
   val {args, blocks, inline, name, returns, raises, start} =
       (* Use fresh variables in the clone to prevent errors in later analyses
       (which assume that variables in distinct functions are distinct) *)
       Function.dest (Function.alphaRename f)
   val newArgs = Vector.concatV (Vector.map2 (args, choices, applyChoice))
   fun buildNewFunc binds = let
      val newBlock = buildBindBlock (Vector.fromList binds, start)
   in
      Function.new {args = newArgs,
                    blocks = Vector.concat [Vector.new1 newBlock, blocks],
                    inline = inline,
                    name = newFuncNamedLike (name, "flat"),
                    raises = raises,
                    returns = returns,
                    start = Block.label newBlock}
   end
in
   case !needBinds of
       [] => Error.bug "No-op flattening decision"
    | binds => buildNewFunc binds
end

datatype flatteningChoiceType =
           NoOp
         | Valid
         | Invalid

fun checkFlatteningChoice (f: Function.t, choices: argChoice vector) = let
   val {args, ...} = Function.dest f
   fun checkFlatten (typedVar) =
       case flattenTupleVar typedVar of
           SOME _ => true
         | NONE => false
   fun checkChoice (typedVar, choice) =
       case choice of
           Preserve => true
         | FlattenTuple => checkFlatten (typedVar)
         | FlattenCon {argTys, ...} =>
           Option.isSome (flattenConVar (typedVar, argTys))
   fun isPreserve c =
       case c of
           Preserve => true
         | _ => false
   val isNoop = Vector.forall (choices, isPreserve)
   val validChoice = if isNoop then NoOp else Valid
in
   if (Vector.length args) = (Vector.length choices) andalso
      Vector.forall2 (args, choices, checkChoice) then
      validChoice
   else
      Invalid

end

datatype varChoice =
         PreserveVar
         | FlattenTupleVar of Var.t vector
         | FlattenConVar of {args: (Var.t * Type.t) vector, con: Con.t}

type varChoiceManager = {
   getVarChoiceProp: Var.t -> varChoice,
   setVarChoiceProp: Var.t * varChoice -> unit,
   getVarTypeProp: Var.t -> Type.t,
   setVarTypeProp: Var.t * Type.t -> unit,
   destroyVarChoiceManagerProps: unit -> unit
}

fun newVarChoiceManager () = let
   (* TODO(pscollins): Consider making "missing" into an error *)
   val {get=getChoice, set=setChoice, destroy=destroyChoice} =
       Property.destGetSetOnce (Var.plist,
                                Property.initConst PreserveVar)
   val {get=getType, set=setType, destroy=destroyType} =
       Property.destGetSetOnce (Var.plist,
                                Property.initRaise ("type lookup", Var.layout))
   fun destroyProps () =
       (destroyChoice(); destroyType())
in
   {getVarChoiceProp = getChoice,
    setVarChoiceProp = setChoice,
    getVarTypeProp = getType,
    setVarTypeProp = setType,
    destroyVarChoiceManagerProps = destroyProps}
end

fun chooseVarsInStatement (vt: varChoiceManager, s: Statement.t) = let
   val {setVarChoiceProp, getVarTypeProp, ...} = vt
   val Statement.T {exp, ty, var=maybeVar} = s
   fun buildLogStmt args =
       Layout.seq ([Layout.str "chooseVarsInStatement: for s=",
                    Statement.layout s,
                    Layout.str " made decision: "] @
                   args)
   fun logNonTupleResultThunk() =
       buildLogStmt ([Layout.str " do not flatten: not a tuple, or no dest"])
   fun addType v =
       (v, getVarTypeProp v)
   fun getTupleDecisionFromParents (parents: Var.t vector) = let
      fun logResultThunk() =
          buildLogStmt ([Layout.str " flatten tuple unless empty: ",
                         Vector.layout Var.layout parents])
      val _ = Control.diagnostic logResultThunk
   in
       (* `unit` is represented by an empty tuple that we don't want to flatten
       through *)
       if Vector.isEmpty parents then
          PreserveVar
       else
          FlattenTupleVar parents
   end
   fun getFlattenConFromParents (argcon as {args, con}) = let
      fun logResultThunk() =
          buildLogStmt ([Layout.str " flatten datatype: parents=(",
                         Vector.layout Var.layout args,
                         Layout.str "), con=",
                         Con.layout con])
      val _ = Control.diagnostic logResultThunk
   in
      FlattenConVar {args=Vector.map (args, addType), con=con}
   end
in
   case (exp, maybeVar) of
       (Exp.Tuple parents, SOME var) =>
       setVarChoiceProp (var, getTupleDecisionFromParents parents)
    | (Exp.ConApp argcon, SOME var) =>
       setVarChoiceProp (var, getFlattenConFromParents argcon)
    | _ => Control.diagnostic logNonTupleResultThunk
end

fun getVarChoice (vt: varChoiceManager, v: Var.t) = let
   val {getVarChoiceProp, ...} = vt
in
   getVarChoiceProp v
end

fun destroyVarChoiceManager (vt: varChoiceManager) = let
   val {destroyVarChoiceManagerProps, ...} = vt
in
   destroyVarChoiceManagerProps()
end

fun markTypeForBinding (vt: varChoiceManager, s: Statement.t) = let
   val {setVarTypeProp, ...} = vt
   val Statement.T {ty, var, ...} = s
in
   case var of
       SOME var => setVarTypeProp (var, ty)
     | _ => ()
end

fun markTypeForArgs (vt: varChoiceManager, func: Function.t) = let
   val {setVarTypeProp, ...} = vt
   val {args, ...} = Function.dest func
   fun doBlock b = Vector.foreach (Block.args b, setVarTypeProp)
in
   (Vector.foreach (args, setVarTypeProp);
    Vector.foreach (Function.blocks func, doBlock))
end


fun newVarChoicesForProgram (p: Program.t) = let
   val vcm = newVarChoiceManager ()
   fun markStatement (s: Statement.t) =
       markTypeForBinding (vcm, s)
   fun markFunction (f: Function.t) =
       markTypeForArgs (vcm, f)
   fun chooseStatement (s: Statement.t) =
       chooseVarsInStatement (vcm, s)

   (* First, record the types associated with every bound variable. Don't use
   the DFS order since it can miss statements. *)
   val _ = foreachFunction (p, markFunction)
   val _ = foreachStatement (p, markStatement)
   (* Next, in a separate pass, make the flattening choice. We do this in two
   passes since the DFS order might not guarantee us that we visit every def
   before its use. *)
   val _ = doWalk (statementWalker chooseStatement, p)
in
   vcm
end

datatype varConsumer =
            AsUnpacked
            | AsCurrent
            | AsAlias of Var.t

type varConsumerManager = {
   getVarConsumersProp: Var.t -> varConsumer list ref,
   destroyVarConsumersProps: unit -> unit,
   funcsMap: funcsMap
}


fun newVarConsumerManager (p: Program.t) = let
   fun newConsumers _ = ref []
   val {get=getConsumers, destroy=destroyConsumers, ...} =
       Property.destGetSetOnce (Var.plist,
                                Property.initFun newConsumers)
in
   {getVarConsumersProp = getConsumers,
    destroyVarConsumersProps = destroyConsumers,
    funcsMap = newFuncsMap p}
end

fun getVarConsumers (vm: varConsumerManager, v: Var.t) = let
   val {getVarConsumersProp, ...} = vm
in
   !(getVarConsumersProp v)
end

fun varConsumerToString varConsumer =
   case varConsumer of
      AsUnpacked => "AsUnpacked"
    | AsCurrent => "AsCurrent"
    | AsAlias v => concat ["AsAlias(", Var.toString v, ")"]

(* Add each `varConsumer` in `s` to `vm`

  * `_ := Select(..., v)` -> AsUnpacked
  * `_ := {ConApp,PrimApp,Tuple}(...v...)` -> AsCurrent
  * `v := Var(v')` -> AsAlias(v')
 *)
fun markConsumersInStatement (vm: varConsumerManager, s: Statement.t) = let
   val {getVarConsumersProp, ...} = vm
   val Statement.T {exp, var=maybeLhs, ...} = s
   fun buildLogStmtThunk (var, decision) = let
      fun thunk () =
          Layout.seq ([Layout.str "markConsumersInStatement: for s=",
                       Statement.layout s,
                       Layout.str " with var=",
                       Var.layout var,
                       Layout.str " added consumer ",
                       Layout.str (varConsumerToString decision)])
   in
      thunk
   end
   fun addConsumer consumer v = let
      val _ = Control.diagnostic (buildLogStmtThunk (v, consumer))
      val consumersRef = getVarConsumersProp v
   in
      List.push (consumersRef, consumer)
   end
   fun addConsumerTo consumer (vs: Var.t vector): unit =
       Vector.foreach (vs, addConsumer consumer)
   val addCurrentConsumer = addConsumerTo AsCurrent
   fun addAliasOf rhs =
      case maybeLhs of
          SOME lhs => addConsumer (AsAlias (lhs)) rhs
        | NONE =>  Error.bug ("Bad alias" ^
                              (Layout.toString (Statement.layout s)))
in
   case exp of
       Exp.ConApp {args, ...} => addCurrentConsumer args
     | Exp.PrimApp  {args, ...} => addCurrentConsumer args
     | Exp.Select {tuple, ...} => addConsumer AsUnpacked tuple
     | Exp.Tuple args => addCurrentConsumer args
     (* This shows up in an example program as

          global_2 := global_1

        and all later references are only to `global_2`, not `global_1`, so we
        have the alias "point upwards" from the new name to the old name, i.e.

          rhs := AsAlias(lhs)
      *)
     | Exp.Var rhs => addAliasOf rhs
     | _ => ()
end

(* Extract all of the `Return(...)`s from `f` *)
fun extractReturns (f: Function.t): (Var.t vector) vector = let
   fun extractInBlock b: (Var.t vector) option =
       case Block.transfer b of
           Transfer.Return rets => SOME rets
         | _ => NONE

in
   Vector.keepAllMap (Function.blocks f, extractInBlock)
end

(* Records the "same-layout-as" relationship induced by function calls and
   similar constructs, i.e. if we have a function definition `f(arg1)`, then the
   call `f(x)` means that `x` is consumed in the same layout as `arg1`.

   * `Goto(args, "label")` + `Block(args', "label", ...)` ->
      args[i] = AsAlias(args'[i])

   * `Call(args, "func", ...)` + `Function(args', "func")` ->
      args[i] = AsAlias(args'[i])

   * `Call(..., "callee", Return.NonTail {"block"}` + `Block(args, "block")` +
     `Function(..., "callee", ...) {
        ...
        Return (vs1)
        ...
        Return (vs2)
        ...
     }` ->
     vs1[i] = vs2[i] = AsAlias(args[i])


  * `Case(..., test="x")` ->
    x = AsUnpacked
 *)
fun markConsumersInTransfer (vm: varConsumerManager, transfer: Transfer.t) = let
   val {getVarConsumersProp, funcsMap, ...} = vm
   val {getFunc, getBlock, ...} = funcsMap
   fun logInputThunk () =
       Layout.seq [Layout.str "markConsumersInTransfer: ",
                   Transfer.layout transfer]
   val _ = Control.diagnostic logInputThunk
   fun markAsUnpacked from = let
      val consumersRef = getVarConsumersProp from
   in
      List.push (consumersRef, AsUnpacked)
   end
   fun markConsumer (from, to) = let
      val consumersRef = getVarConsumersProp from
   in
      List.push (consumersRef, AsAlias to)
   end
   fun markConsumers (froms, tos) =
       Vector.foreach2 (froms, tos, markConsumer)
   fun extractVar (var, _) = var
   fun extractVars typedVars = Vector.map (typedVars, extractVar)
   fun getBlockArgs (l: Label.t): Var.t vector = let
      val Block.T {args, ...} = getBlock l
   in
      extractVars args
   end
   fun getFuncArgs funcLabel = let
      val {args, ...} = Function.dest (getFunc funcLabel)
   in
      extractVars args
   end
   fun bindArgs (args, funcLabel) =
      markConsumers (args, getFuncArgs funcLabel)
   fun getAllReturns funcLabel =
       extractReturns (getFunc funcLabel)
   fun bindRetsToBlock (func, returnToLabel) = let
      val returnToBlockArgs = getBlockArgs returnToLabel
      val allReturns: (Var.t vector) vector =
          getAllReturns func
      fun bindReturns returns =
          markConsumers (returns, returnToBlockArgs)
   in
      Vector.foreach (allReturns, bindReturns)
   end
   fun maybeBindRets (func, return) =
       case return of
           Return.NonTail {cont=label, ...} =>
           bindRetsToBlock (func, label)
         (* `Dead` and `Tail` do not bind *)
         | _ => ()
in
   case transfer of
       Transfer.Goto {args, dst} =>
       markConsumers (args, getBlockArgs dst)
     | Transfer.Call {args, func, return, ...} =>
       (bindArgs (args, func);
        maybeBindRets (func, return))
     | Transfer.Case {test, ...} => markAsUnpacked test
     (* `Return` does not bind (it is handled in `Call`)
       `Raise` does not bind
        TODO(pscollins): Spork/spoin?
     *)
     | _ => ()
end


fun destroyVarConsumerManager (vc: varConsumerManager) = let
   val {destroyVarConsumersProps, funcsMap, ...} = vc
   val {destroyFuncsMap, ...} = funcsMap
in
   destroyVarConsumersProps();
   destroyFuncsMap()
end

fun newVarConsumersForProgram (p: Program.t): varConsumerManager = let
   val {beforeFunc, afterFunc, beforeBlock, ...} = defaultWalker 
   val vm = newVarConsumerManager p
   fun doBlock b = markConsumersInTransfer (vm, Block.transfer b)
   fun doStatement s = markConsumersInStatement (vm, s)
   val walker = {beforeFunc = beforeFunc,
                 afterFunc = afterFunc,
                 beforeBlock = beforeBlock,
                 afterBlock = doBlock,
                 statement = doStatement}
   val _ = doWalk (walker, p)
in
   vm
end

fun newVarConsumerManagerFromAssignments (assignments) = let
   val dummyLabel = Func.newString "dummy"
   val emptyProgram =
      Program.T {datatypes=Vector.new0(),
                 functions=[],
                 globals=Vector.new0(),
                 main=dummyLabel}
   val vm = newVarConsumerManager emptyProgram
   val {getVarConsumersProp, ...} = vm
   fun doAssignment (v, consumers) =
       getVarConsumersProp v := consumers
   val _ = List.foreach (assignments, doAssignment)
in
   vm
end

datatype varAliasPolicy =
         DropAlias
         | UnionAlias
fun resolveAliases (policy: varAliasPolicy, vc: varConsumerManager)
                   (consumers: varConsumer list) = let
   val {getVarConsumersProp, ...} = vc
   fun mkVisitedProp _ = ref false
   val {get=getVisitedProp, destroy=destroyVisitedProp, ...} =
       Property.destGetSetOnce (Var.plist,
                                Property.initFun mkVisitedProp)
   (* Marks v' as visited and returns previous state *)
   fun markSeen v' = let
      val seen = getVisitedProp v'
      val wasSeen = !seen
      val _ = seen := true
   in
      wasSeen
   end
   fun doResolve v = let
      val found = ref []
      fun visitConsumer consumer =
          case consumer of
              AsAlias v' => resolve v'
           | _ => List.push (found, consumer)
      and resolve v' =
          if markSeen v' then ()
          else
             List.foreach (!(getVarConsumersProp v'),
                           visitConsumer)
      val _ = resolve v
   in
      !found
   end
   fun processConsumer consumer =
       case (policy, consumer) of
           (DropAlias, AsAlias _) => []
         | (UnionAlias, AsAlias v) => doResolve v
         | _ => [consumer]
   val result =
       List.concatMap (consumers, processConsumer)
   val _ = destroyVisitedProp()
in
   result
end

type functionManager = {
   getOrCreateFlattenedFunc: (Func.t * argChoice vector) -> Func.t,
   pendingFuncs: Function.t list ref,
   destroyFunctionManagerState: unit -> unit
}

fun choiceLayout c =
   case c of
      Preserve => Layout.str "Preserve"
    | FlattenTuple => Layout.str "FlattenTuple"
    | FlattenCon {argTys, con}  =>
      Layout.seq [
         Layout.str "FlattenCon",
         Layout.record [
            ("con", Con.layout con),
            ("argTys", Vector.layout Type.layout argTys)
         ]
      ]

fun choiceEqual (l, r) = let
   fun compareArg ({argTys, con},
                   {argTys=argTys', con=con'}) =
       (Con.equals (con, con')) andalso
       Vector.equals (argTys, argTys', Type.equals)
in
    case (l, r) of
        (Preserve, Preserve) => true
      | (FlattenTuple, FlattenTuple) => true
      | (FlattenCon arg, FlattenCon arg') =>
        compareArg (arg, arg')
      | _ => false
end

fun newFunctionManager (p: Program.t) = let
   (* TODO(pscollins): Since the scheme below doesn't 'follow through'
   already-flattened functions, we'll need to destroy and recreate it after each
   iteration of flattening, which will result in unnecessary flattened
   functions. Optimize in the future. *)

   val pendingFuncs: Function.t list ref = ref []
   fun appendFunc (f: Function.t) = let
      val newPendingFuncs = f::(!pendingFuncs)
   in
      pendingFuncs := newPendingFuncs
   end
   (* First, collect Func.t -> Function mappings *)
   val {getFunc, destroyFuncsMap, ...} = newFuncsMap p

   (* Next, set up a hook to create new flattened functions when necessary

   For simplicity, we attach a list of `(flattening choice, func name)` to each
   unflattened function.

   TODO(pscollins): Optimize this representation. *)
   type flattenedFunc = (argChoice vector * Func.t)
   fun createNewFlattenedFuncList (_): flattenedFunc list ref = ref []

   val {get=getFlattenedFuncList, destroy=destroyFlattenedFuncs,
        ...} = Property.destGetSetOnce
                   (Func.plist,
                    Property.initFun createNewFlattenedFuncList)

   (* Creates a new flattened function for the specified choice *)
   fun createFlattenedFunc
           (originalName: Func.t, choices: argChoice vector): Function.t = let
      val original = getFunc originalName
      fun doBuildFlattenedFunction() = let
         val flattenedFunction = buildFlattenedFunction (original,
                                                         choices)
         val _ = appendFunc flattenedFunction
      in
         flattenedFunction
      end
   in
      case checkFlatteningChoice (original, choices) of
       NoOp => original
     | Valid => doBuildFlattenedFunction()
     | Invalid => Error.bug "Invalid flattening decision"
   end

   (* If we already have a flattened version of `f` for `choice`, returns it.
   Otherwise, builds a flattened function for `f` under `choice` and adds it to
   the list of for `f`. *)
   fun getOrCreateFlattenedFunc (f: Func.t, choices: argChoice vector): Func.t = let
      fun logInputThunk () = let
         open Layout
      in
         seq [str "getOrCreateFlattenedFunc: looking for ",
              Func.layout f,
              Layout.str " with choices ",
              Vector.layout choiceLayout choices]
      end
      fun doLogChoice (newF) = let
         open Layout
      in
         seq [str "getOrCreateFlattenedFunc: created new function ",
              Func.layout newF,
              str " from ",
              Func.layout f]
      end
      val _ = Control.diagnostic logInputThunk
      val flattenedFuncList: flattenedFunc list ref = getFlattenedFuncList f
      fun flattenedFuncMatches (choices', _) =
          Vector.equals (choices', choices,
                         choiceEqual)
      fun addNewFlattenedFunc () = let
         val newFunc = createFlattenedFunc (f, choices)
         val newF = Function.name newFunc
         val _ = Control.diagnostic (fn () => doLogChoice newF)
         val _ = List.push (flattenedFuncList, (choices, newF))
      in
         newF
      end
   in
      case List.peek (!flattenedFuncList,
                      flattenedFuncMatches)  of
          (* If we already have a flattened function for `choices`, return it
             here *)
          SOME (_, matchedFunc) => (
             Control.diagnostic (fn () => let open Layout in
                seq [str "getOrCreateFlattenedFunc: found matched function ",
                     Func.layout matchedFunc]
             end);
             matchedFunc
          )
        (* Otherwise, build a new one *)
        | _ => addNewFlattenedFunc()
   end

   fun destroyFunctionManagerState() = let
      val _ = destroyFlattenedFuncs()
      val _ = destroyFuncsMap()
   in
      ()
   end
in
   {getOrCreateFlattenedFunc = getOrCreateFlattenedFunc,
    pendingFuncs = pendingFuncs,
    destroyFunctionManagerState = destroyFunctionManagerState}
end

fun getOrCreateFunc
        (fm: functionManager,
         f: Func.t, choices: argChoice vector) = let
   val {getOrCreateFlattenedFunc, ...} = fm
in
   getOrCreateFlattenedFunc (f, choices)
end

fun extractNewFunctions (fm: functionManager) = let
   val {pendingFuncs, ...} = fm
   val currFuncs = !pendingFuncs
   val _ = pendingFuncs := []
in
   currFuncs
end

fun destroyFunctionManager (fm: functionManager) = let
   val {pendingFuncs, destroyFunctionManagerState, ...} = fm
in
   case !pendingFuncs of
       [] => destroyFunctionManagerState ()
     | funcs => Error.bug "Tried to destroy nonempty `fm`"
end

datatype flatteningPolicy =
           FlattenAlways
         | FlattenForAnyUnpack
         | FlattenForAllUnpack

fun updateChoiceForPolicy policy (varChoice, varConsumers) = let
   fun isUnpacked consumer =
       case consumer of
           AsUnpacked => true
         | AsCurrent => false
         | AsAlias _ => Error.bug "Must filter AsAlias!"
   fun hasConsumerType wantType =
       List.exists (varConsumers, wantType)
   fun allConsumerType wantType =
       List.forall (varConsumers, wantType)
in
   case (policy, varChoice) of
       (FlattenAlways, _) => varChoice
     | (_, PreserveVar) => varChoice
     | (FlattenForAnyUnpack, _) =>
       if hasConsumerType isUnpacked then varChoice
       else PreserveVar
     | (FlattenForAllUnpack, _) =>
      if allConsumerType isUnpacked then varChoice
      else PreserveVar
     end

datatype flattenableTypesPolicy =
         FlattenAnyType
         | FlattenOnlyTuple
         | FlattenOnlyConApp

fun updateChoiceForAllowedTypes policy vc =
   case (policy, vc) of
       (FlattenOnlyTuple, FlattenConVar _) => PreserveVar
     | (FlattenOnlyConApp, FlattenTupleVar _) => PreserveVar
     | _ => vc


fun varChoiceToArgChoice (vc: varChoice): argChoice = let
   fun extractTy (_, t) = t
in
   case vc of
       PreserveVar => Preserve
     | FlattenTupleVar _ => FlattenTuple
     | FlattenConVar {args, con} =>
       FlattenCon {argTys = Vector.map (args, extractTy),
                   con=con}
end


(* Given a flattening choice for the constituent vars of `originalArgs`, returns
the argument vector to pass to the flattened function *)
fun buildCallArgs (originalArgs: Var.t vector,
                   varChoices: varChoice vector) = let
   fun extractVar (v, _) = v
   fun buildCallArg (originalArg, varChoice) =
       case varChoice of
           PreserveVar => Vector.new1 originalArg
         | FlattenTupleVar parents => parents
         | FlattenConVar {args, ...} => Vector.map (args, extractVar)
in
   Vector.concatV (
   Vector.map2 (originalArgs, varChoices, buildCallArg))
end

fun flattenOnce (flattenPolicy, resolvePolicy, allowedTypesPolicy) (p: Program.t) = let
   val vm = newVarChoicesForProgram p
   val vc = newVarConsumersForProgram p
   val fm = newFunctionManager p
   val resolve = resolveAliases (resolvePolicy, vc)
   fun getChoice v = getVarChoice (vm, v)
   fun getConsumers v = resolve (getVarConsumers (vc, v))
   fun getFunc (original, argChoices) =
       getOrCreateFunc (fm, original, argChoices)
   val updateChoice = (updateChoiceForAllowedTypes allowedTypesPolicy)
                      o updateChoiceForPolicy flattenPolicy
   fun rewriteTransfer (t: Transfer.t) = let
      fun buildCall (args, func, inline, return) = let
         (* Make a flattening decision for each argument by collecting all of
         the tags for each concrete argument... *)
         val varChoices = Vector.map (args, getChoice)
         (* ...and the (resolved) usage info for each formal parameter... *)
         val varConsumers = Vector.map (args, getConsumers)
         (* ...and applying the policy *)
         val varChoices' = Vector.map2 (varChoices, varConsumers,
                                        updateChoice)
         (* Construct the call argument *)
         val args' = buildCallArgs (args, varChoices')
         (* Construct the flattened function *)
         val argChoices = Vector.map (varChoices', varChoiceToArgChoice)
         val func' = getFunc (func, argChoices)
      in
         (* Return a call to the flattened function (perhaps unchanged) *)
         Transfer.Call {args=args',
                        func=func',
                        inline=inline,
                        return=return}
      end
   in
      case t of
          (* For now, only Call is supported

           TODO(pscollins): Ideally we'd support goto-with-args as well
           *)
          Transfer.Call {args, func, inline, return} =>
          SOME (buildCall (args, func, inline, return))
        | _ => NONE
   end

   fun maybeRewriteBlock (b: Block.t): Block.t option = let
      val Block.T {args, label, statements, transfer} = b
   in
      case rewriteTransfer transfer of
          SOME transfer' => SOME (Block.T {args=args,
                                           label=label,
                                           statements=statements,
                                           transfer=transfer'})
        | NONE => NONE
   end

   (* Extracts new functions from `fm` and adds them to `p'`, or
      returns `NONE` *)
   fun maybeAppendNewFns (p': Program.t) = let
      val Program.T {datatypes, functions, globals, main} = p'
   in
      case extractNewFunctions fm of
          [] => NONE
        | newFns => SOME (Program.T {datatypes=datatypes,
                                     functions=List.append (newFns,
                                                            functions),
                                     globals=globals,
                                     main = main})
   end
   val p' = maybeAppendNewFns (mapBlocks (p, maybeRewriteBlock))
   val _ = destroyFunctionManager fm
   val _ = destroyVarChoiceManager vm
   val _ = destroyVarConsumerManager vc
in
   p'
end

fun transform (p: Program.t): Program.t =
    let
       val policy =
          case !Control.preFlattenConsumerPolicy of
             Control.PreFlattenConsumerPolicy.Always => FlattenAlways
           | Control.PreFlattenConsumerPolicy.AnyUnpack => FlattenForAnyUnpack
           | Control.PreFlattenConsumerPolicy.AllUnpack => FlattenForAllUnpack
       val resolvePolicy =
          case !Control.preFlattenResolvePolicy of
             Control.PreFlattenResolvePolicy.Global => UnionAlias
           | Control.PreFlattenResolvePolicy.Local => DropAlias
       val typesPolicy =
          case !Control.preFlattenTypesPolicy of
             Control.PreFlattenTypesPolicy.Any => FlattenAnyType
           | Control.PreFlattenTypesPolicy.Tuple => FlattenOnlyTuple
           | Control.PreFlattenTypesPolicy.Con => FlattenOnlyConApp
       fun loop (p, n) =
          if n >= !Control.preFlattenMaxIters
             then p
          else
             case flattenOnce (policy, resolvePolicy, typesPolicy) p of
                NONE => p
              | SOME p' => loop (shrink p', n + 1)
    in
       loop (p, 0)
    end
end
