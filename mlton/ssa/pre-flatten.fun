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

fun newFuncNamedLike (name: Func.t, suffix) = let
   val currName = Func.toString name
in
   Func.newString (concat [currName, "_", suffix])
end

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
   val isNoop = Vector.forall (choices, fn c => c = Preserve)
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

datatype varConsumer =
            AsUnpacked
            | AsCurrent
            | AsAlias of Var.t

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
   fun buildLogStmt args =
       Layout.seq ([Layout.str "chooseVarsInStatement: for s=",
                    Statement.layout s,
                    Layout.str " made decision: "] @
                   args @ [Layout.str "\n"])
   fun logNonTupleResultThunk() =
       buildLogStmt ([Layout.str " do not flatten: not a tuple, or no dest"])

   fun getDecisionFromParents (parents: Var.t vector) = let
      fun logResultThunk() =
          buildLogStmt ([Layout.str " flatten unless empty: ",
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
in
   case (exp, maybeVar) of
       (Exp.Tuple parents, SOME var) =>
       setVarChoiceProp (var, getDecisionFromParents parents)
    | _ => Control.diagnostic logNonTupleResultThunk
end

fun getVarChoice (vt: varChoiceManager, v: Var.t) = let
   val {getVarChoiceProp, ...} = vt
in
   getVarChoiceProp v
end

(* Add each `varConsumer` in `s` to `vm`

  * `_ := Select(..., v)` -> AsUnpacked
  * `_ := {ConApp,PrimApp,Tuple}(...v...)` -> AsCurrent
  * `v := Var(v')` -> AsAlias(v')
 *)
fun markConsumersInStatement (vm: varChoiceManager, s: Statement.t) = ()

fun getVarConsumers (vm: varChoiceManager, v: Var.t) = []

fun destroyVarChoiceManager (vt: varChoiceManager) = let
   val {destroyVarChoiceProps, ...} = vt
in
   destroyVarChoiceProps()
end

fun newVarChoicesForProgram (p: Program.t) = let
   val vcm = newVarChoiceManager ()
   fun doStatement (s: Statement.t) =
       chooseVarsInStatement (vcm, s)
   val walker = statementWalker doStatement
   val _ = doWalk (walker, p)
in
   vcm
end

type functionManager = {
   getOrCreateFlattenedFunc: (Func.t * argChoice vector) -> Func.t,
   pendingFuncs: Function.t list ref,
   destroyFunctionManagerState: unit -> unit
}

fun choiceString c =
    case c of
        Preserve => "Preserve"
     |  FlattenTuple => "FlattenTuple"

fun choiceLayout c =
    Layout.str (choiceString c)

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
   val {get=getFunc, set=setFunc, destroy=destroyFuncs} =
       Property.destGetSetOnce (Func.plist,
                                Property.initRaise ("function lookup", Func.layout))
   fun addFuncToMapping (f: Function.t) = setFunc (Function.name f, f)

   (* Use foreachFunctin rather than `walker` because the DFS traversal pattern
   doesn't reach disconnected functions, and so a program containing any such
   function hits the `initRaise` above. The ordering of our `addFuncToMapping`
   calls doesn't matter, so we might as well avoid the error by just setting up
   the mapping for all functions. *)
   val _ = foreachFunction (p, addFuncToMapping)

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
              Vector.layout choiceLayout choices,
              str "\n"]
      end
      fun doLogChoice (newF) = let
         open Layout
      in
         seq [str "getOrCreateFlattenedFunc: created new function ",
              Func.layout newF,
              str " from ",
              Func.layout f, str "\n"]
      end
      val _ = Control.diagnostic logInputThunk
      val flattenedFuncList: flattenedFunc list ref = getFlattenedFuncList f
      fun flattenedFuncMatches (choices', _) =
          Vector.equals (choices', choices,
                         fn (l, r) => l = r)
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
      val _ = destroyFuncs()
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

fun varChoiceToArgChoice (vc: varChoice): argChoice =
    case vc of
        PreserveVar => Preserve
      | FlattenTupleVar _ => FlattenTuple


(* Given a flattening choice for the constituent vars of `originalArgs`, returns
the argument vector to pass to the flattened function *)
fun buildCallArgs (originalArgs: Var.t vector,
                   varChoices: varChoice vector) = let
   fun buildCallArg (originalArg, varChoice) =
       case varChoice of
           PreserveVar => Vector.new1 originalArg
         | FlattenTupleVar parents => parents
in
   Vector.concatV (
   Vector.map2 (originalArgs, varChoices, buildCallArg))
end

fun flattenOnce (p: Program.t) = let
   val vm = newVarChoicesForProgram p
   val fm = newFunctionManager p
   fun getChoice v = getVarChoice (vm, v)
   fun getFunc (original, argChoices) =
       getOrCreateFunc (fm, original, argChoices)
   fun rewriteTransfer (t: Transfer.t) = let
      fun buildCall (args, func, inline, return) = let
         (* Make a flattening decision for each argument *)
         val varChoices = Vector.map (args, getChoice)
         (* Construct the call argument *)
         val args' = buildCallArgs (args, varChoices)
         (* Construct the flattened function *)
         val argChoices = Vector.map (varChoices, varChoiceToArgChoice)
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
in
   p'
end

fun transform (p: Program.t): Program.t =
    let
       fun loop (p, n) =
          if n >= !Control.preFlattenMaxIters
             then p
          else
             case flattenOnce p of
                NONE => p
              | SOME p' => loop (shrink p', n + 1)
    in
       loop (p, 0)
    end
end
