functor ExtractSsaSubgraph (S: EXTRACT_SSA_SUBGRAPH_STRUCTS): EXTRACT_SSA_SUBGRAPH =
struct

open S

structure VarSet = UnorderedSet (Var)
structure TyconSet = UnorderedSet (Tycon)

datatype def =
   Stmt of Statement.t
 | FArg of Function.t * int
 | BArg of Block.t * int

datatype predecessor =
   PGoto of Block.t * Var.t vector
 | PCase of Block.t * Var.t
 | PCallReturn of Block.t * Func.t
 | PCallHandler of Block.t * Func.t
 | PRuntimeReturn of Block.t * Var.t vector

datatype use_site =
   UStmt of Statement.t
 | UTr of Block.t * Transfer.t

fun stmtTy (Statement.T {ty, ...}) = ty

fun isolateSubgraph (program: Program.t, rootVar: Var.t): Program.t = let
   val Program.T {datatypes, functions, globals, main} = program

   (* Properties for lookups and mappings *)
   val {get = getDefOpt, set = setDef, destroy = destroyDef} =
      Property.destGetSet (Var.plist, Property.initConst NONE)

   val {get = getCallSites, set = setCallSites, destroy = destroyCallSites} =
      Property.destGetSet (Func.plist, Property.initConst [])

   val {get = getReturns, set = setReturns, destroy = destroyReturns} =
      Property.destGetSet (Func.plist, Property.initConst [])

   val {get = getRaises, set = setRaises, destroy = destroyRaises} =
      Property.destGetSet (Func.plist, Property.initConst [])

   val {get = getPredecessors, set = setPredecessors, destroy = destroyPredecessors} =
      Property.destGetSet (Label.plist, Property.initConst [])

   val {get = getUses, set = setUses, destroy = destroyUses} =
      Property.destGetSet (Var.plist, Property.initConst [])

   val {get = getBlockFunc, set = setBlockFunc, destroy = destroyBlockFunc} =
      Property.destGetSet (Label.plist, Property.initRaise ("block function", Label.layout))

   val {get = funcToFunction, set = setFuncToFunction, destroy = destroyFuncToFunction} =
      Property.destGetSet (Func.plist, Property.initRaise ("func to function", Func.layout))

   val {get = labelToBlock, set = setLabelToBlock, destroy = destroyLabelToBlock} =
      Property.destGetSet (Label.plist, Property.initRaise ("label to block", Label.layout))

   (* 1. Populate the mappings by walking the program *)
   fun visitStatement (s: Statement.t) =
      case Statement.var s of
         NONE => ()
       | SOME x => setDef (x, SOME (Stmt s))

   val _ = Vector.foreach (globals, visitStatement)

   fun visitFunction (f: Function.t) = let
      val {args, blocks, name, ...} = Function.dest f
      val _ = setFuncToFunction (name, f)
      val _ = Vector.foreachi (args, fn (idx, (x, _)) =>
         setDef (x, SOME (FArg (f, idx))))
      fun visitBlock (b: Block.t) = let
         val Block.T {args = bArgs, label, statements, transfer} = b
         val _ = setBlockFunc (label, f)
         val _ = setLabelToBlock (label, b)
         val _ = Vector.foreachi (bArgs, fn (idx, (x, _)) =>
            setDef (x, SOME (BArg (b, idx))))
         val _ = Vector.foreach (statements, visitStatement)

         (* Predecessors and calls/returns/raises *)
         val _ =
            case transfer of
               Transfer.Goto {args = gArgs, dst} =>
                  setPredecessors (dst, PGoto (b, gArgs) :: getPredecessors dst)
             | Transfer.Case {test, cases, default} => let
                  fun addCaseTarget lbl =
                     setPredecessors (lbl, PCase (b, test) :: getPredecessors lbl)
               in
                  Cases.foreach (cases, addCaseTarget);
                  Option.app (default, addCaseTarget)
               end
             | Transfer.Call {func, return, args = cArgs, ...} => let
                  val _ = setCallSites (func, (b, cArgs, return) :: getCallSites func)
               in
                  case return of
                     Return.NonTail {cont, handler} => (
                        setPredecessors (cont, PCallReturn (b, func) :: getPredecessors cont);
                        case handler of
                           Handler.Handle lbl =>
                              setPredecessors (lbl, PCallHandler (b, func) :: getPredecessors lbl)
                         | _ => ()
                     )
                   | _ => ()
               end
             | Transfer.Runtime {args = rArgs, return, ...} =>
                  setPredecessors (return, PRuntimeReturn (b, rArgs) :: getPredecessors return)
             | Transfer.Return args =>
                  setReturns (name, (b, args) :: getReturns name)
             | Transfer.Raise args =>
                  setRaises (name, (b, args) :: getRaises name)
             | _ => ()
      in
         ()
      end
      val _ = Vector.foreach (blocks, visitBlock)
   in
      ()
   end
   val _ = List.foreach (functions, visitFunction)

   (* Walk again to collect uses *)
   fun visitStatementUses (s: Statement.t) =
      Exp.foreachVar (Statement.exp s, fn x => setUses (x, UStmt s :: getUses x))

   val _ = Vector.foreach (globals, visitStatementUses)

   fun visitFunctionUses (f: Function.t) = let
      val {blocks, ...} = Function.dest f
      fun visitBlockUses (b: Block.t) = let
         val Block.T {statements, transfer, ...} = b
         val _ = Vector.foreach (statements, visitStatementUses)
         val _ = Transfer.foreachVar (transfer, fn x => setUses (x, UTr (b, transfer) :: getUses x))
      in
         ()
      end
   in
      Vector.foreach (blocks, visitBlockUses)
   end
   val _ = List.foreach (functions, visitFunctionUses)

   (* Worklist reachability search *)
   val visitedVars = ref VarSet.empty
   val todo = ref []

   fun addVar (x: Var.t) =
      if VarSet.contains (!visitedVars, x) then ()
      else (
         visitedVars := VarSet.add (!visitedVars, x);
         todo := x :: !todo
      )

   val _ = addVar rootVar

   fun processWorklist () =
      case !todo of
         [] => ()
       | v :: rest => let
            val _ = todo := rest
            (* Upward transitions *)
            val _ =
               case getDefOpt v of
                  NONE => ()
                | SOME (Stmt s) => Exp.foreachVar (Statement.exp s, addVar)
                | SOME (FArg (g, idx)) => let
                     fun addCall (_, args, _) =
                        if idx < Vector.length args then addVar (Vector.sub (args, idx)) else ()
                  in
                     List.foreach (getCallSites (Function.name g), addCall)
                  end
                | SOME (BArg (b, idx)) => let
                     fun addPred pred =
                        case pred of
                           PGoto (_, args) =>
                              if idx < Vector.length args then addVar (Vector.sub (args, idx)) else ()
                         | PCase (_, test) => addVar test
                         | PCallReturn (_, callee) => let
                              fun addRet (_, args) =
                                 if idx < Vector.length args then addVar (Vector.sub (args, idx)) else ()
                           in
                              List.foreach (getReturns callee, addRet)
                           end
                         | PCallHandler (_, callee) => let
                              fun addRaise (_, args) =
                                 Vector.foreach (args, addVar)
                           in
                              List.foreach (getRaises callee, addRaise)
                           end
                         | PRuntimeReturn (_, args) =>
                              Vector.foreach (args, addVar)
                  in
                     List.foreach (getPredecessors (Block.label b), addPred)
                  end

            (* Downward transitions *)
            val _ = let
               fun addUse site =
                  case site of
                     UStmt s => Option.app (Statement.var s, addVar)
                   | UTr (b, t) =>
                        case t of
                           Transfer.Return args => let
                              val f = getBlockFunc (Block.label b)
                              val funcName = Function.name f
                              val idxOpt = Vector.index (args, fn x => Var.equals (x, v))
                           in
                              case idxOpt of
                                 NONE => ()
                               | SOME idx => let
                                    fun processCall (callerBlock, callArgs, return) =
                                       case return of
                                          Return.Dead => ()
                                        | Return.NonTail {cont, ...} => let
                                             val contBlock = labelToBlock cont
                                             val contArgs = Block.args contBlock
                                          in
                                             if idx < Vector.length contArgs then
                                                addVar (#1 (Vector.sub (contArgs, idx)))
                                             else ()
                                          end
                                        | Return.Tail => let
                                             val callerFunc = getBlockFunc (Block.label callerBlock)
                                          in
                                             List.foreach (getReturns (Function.name callerFunc), fn (_, retArgs) =>
                                                if idx < Vector.length retArgs then addVar (Vector.sub (retArgs, idx)) else ())
                                          end
                                 in
                                    List.foreach (getCallSites funcName, processCall)
                                 end
                           end
                         | Transfer.Raise args => let
                              val f = getBlockFunc (Block.label b)
                              val funcName = Function.name f
                           in
                              List.foreach (getCallSites funcName, fn (callerBlock, _, return) =>
                                 case return of
                                    Return.NonTail {handler = Handler.Handle handlerLabel, ...} => let
                                       val handlerBlock = labelToBlock handlerLabel
                                       val handlerArgs = Block.args handlerBlock
                                    in
                                       if Vector.length handlerArgs > 0 then
                                          addVar (#1 (Vector.sub (handlerArgs, 0)))
                                       else ()
                                    end
                                  | _ => ())
                           end
                         | Transfer.Goto {args, dst} => let
                              val idxOpt = Vector.index (args, fn x => Var.equals (x, v))
                           in
                              case idxOpt of
                                 NONE => ()
                               | SOME idx => let
                                    val dstBlock = labelToBlock dst
                                    val dstArgs = Block.args dstBlock
                                 in
                                    if idx < Vector.length dstArgs then
                                       addVar (#1 (Vector.sub (dstArgs, idx)))
                                    else ()
                                 end
                           end
                         | Transfer.Call {func, args, ...} => let
                              val idxOpt = Vector.index (args, fn x => Var.equals (x, v))
                           in
                              case idxOpt of
                                 NONE => ()
                               | SOME idx => let
                                    val callee = funcToFunction func
                                    val calleeArgs = #args (Function.dest callee)
                                 in
                                    if idx < Vector.length calleeArgs then
                                       addVar (#1 (Vector.sub (calleeArgs, idx)))
                                    else ()
                                 end
                           end
                         | Transfer.Case {cases, default, ...} => let
                              fun addTarget lbl = let
                                 val dstBlock = labelToBlock lbl
                              in
                                 Vector.foreach (Block.args dstBlock, fn (param, _) => addVar param)
                              end
                           in
                              Cases.foreach (cases, addTarget);
                              Option.app (default, addTarget)
                           end
                         | Transfer.Runtime {return, ...} => let
                              val dstBlock = labelToBlock return
                           in
                              Vector.foreach (Block.args dstBlock, fn (param, _) => addVar param)
                           end
                         | _ => ()
            in
               List.foreach (getUses v, addUse)
            end
         in
            processWorklist ()
         end

   val _ = processWorklist ()

   val wantVars = !visitedVars

   (* 2. Pruning phase *)
   val {get = isBlockKept, set = setBlockKept, destroy = destroyBlockKept} =
      Property.destGetSet (Label.plist, Property.initConst false)

   val {get = isFuncKept, set = setFuncKept, destroy = destroyFuncKept} =
      Property.destGetSet (Func.plist, Property.initConst false)

   val {get = getFuncKeptIndices, set = setFuncKeptIndices, destroy = destroyFuncKeptIndices} =
      Property.destGetSet (Func.plist, Property.initConst [])

   val {get = getBlockKeptIndices, set = setBlockKeptIndices, destroy = destroyBlockKeptIndices} =
      Property.destGetSet (Label.plist, Property.initConst [])

   val {get = isTyconKept, set = setTyconKept, destroy = destroyTyconKept} =
      Property.destGetSet (Tycon.plist, Property.initConst false)

   fun collectTycons (ty: Type.t): unit =
      case Type.dest ty of
         Type.Array t => collectTycons t
       | Type.CPointer => ()
       | Type.Datatype tycon => setTyconKept (tycon, true)
       | Type.IntInf => ()
       | Type.Real _ => ()
       | Type.Ref t => collectTycons t
       | Type.Thread => ()
       | Type.Tuple ts => Vector.foreach (ts, collectTycons)
       | Type.Vector t => collectTycons t
       | Type.Weak t => collectTycons t
       | Type.Word _ => ()

   fun keepStmt (s: Statement.t): bool = let
      val acc = ref false
      val _ = Option.app (Statement.var s, fn x =>
         if VarSet.contains (wantVars, x) then acc := true else ())
      val _ = Exp.foreachVar (Statement.exp s, fn x =>
         if VarSet.contains (wantVars, x) then acc := true else ())
   in
      !acc
   end

   (* Pre-determine which blocks and functions are kept, and pre-compute argument indices *)
   fun analyzeFunctionPruning (f: Function.t) = let
      val {args, blocks, start, name, ...} = Function.dest f
      val fKept = ref false

      val keptFuncIndices =
         Vector.foldri (args, [], fn (idx, (v, ty), acc) =>
            if VarSet.contains (wantVars, v) then (
               collectTycons ty;
               idx :: acc
            ) else acc)
      val _ = setFuncKeptIndices (name, keptFuncIndices)

      fun analyzeBlock b = let
         val Block.T {args = bArgs, label, statements, ...} = b
         val bKept = ref false

         val keptBlockIndices =
            Vector.foldri (bArgs, [], fn (idx, (v, ty), acc) =>
               if VarSet.contains (wantVars, v) then (
                  collectTycons ty;
                  bKept := true;
                  idx :: acc
               ) else acc)
         val _ = setBlockKeptIndices (label, keptBlockIndices)

         val _ = Vector.foreach (statements, fn s =>
            if keepStmt s then (
               bKept := true;
               collectTycons (stmtTy s);
               Exp.foreachVar (Statement.exp s, fn x =>
                  case getDefOpt x of
                     NONE => ()
                   | SOME (Stmt sDef) => collectTycons (stmtTy sDef)
                   | SOME (FArg (funcDef, idxDef)) =>
                        collectTycons (#2 (Vector.sub (#args (Function.dest funcDef), idxDef)))
                   | SOME (BArg (blkDef, idxDef)) =>
                        collectTycons (#2 (Vector.sub (Block.args blkDef, idxDef))))
            ) else ())

         val _ = if !bKept then (
            setBlockKept (label, true);
            fKept := true
         ) else ()
      in
         ()
      end
      val _ = Vector.foreach (blocks, analyzeBlock)
      val _ = if !fKept orelse Func.equals (name, main) then (
         setFuncKept (name, true);
         setBlockKept (start, true)
      ) else ()
   in
      ()
   end

   val _ = List.foreach (functions, analyzeFunctionPruning)

   (* Pruning helper functions *)
   fun filterVectorByIndices (vec, indices) =
      Vector.fromList (List.map (indices, fn idx => Vector.sub (vec, idx)))

   fun filterArgsForCall (func, args) =
      filterVectorByIndices (args, getFuncKeptIndices func)

   fun filterArgsForGoto (dst, args) =
      filterVectorByIndices (args, getBlockKeptIndices dst)

   fun filterTransfer (t: Transfer.t): Transfer.t =
      case t of
         Transfer.Bug => Transfer.Bug
       | Transfer.Call {args, func, inline, return} =>
            if not (isFuncKept func) then Transfer.Bug
            else
               let
                  val return' =
                     case return of
                        Return.Dead => Return.Dead
                      | Return.Tail => Return.Tail
                      | Return.NonTail {cont, handler} =>
                           if not (isBlockKept cont) then Return.Dead
                           else
                              let
                                 val handler' =
                                    case handler of
                                       Handler.Handle lbl =>
                                          if isBlockKept lbl then handler else Handler.Dead
                                     | h => h
                              in
                                 Return.NonTail {cont = cont, handler = handler'}
                              end
               in
                  Transfer.Call {args = filterArgsForCall (func, args),
                                 func = func,
                                 inline = inline,
                                 return = return'}
               end
       | Transfer.Case {test, cases, default} =>
            let
               val allKept = ref true
               fun checkTarget lbl =
                  if not (isBlockKept lbl) then allKept := false else ()
               val _ = Cases.foreach (cases, checkTarget)
               val _ = Option.app (default, checkTarget)
            in
               if not (!allKept) then Transfer.Bug
               else t
            end
       | Transfer.Goto {args, dst} =>
            if not (isBlockKept dst) then Transfer.Bug
            else Transfer.Goto {args = filterArgsForGoto (dst, args), dst = dst}
       | Transfer.Runtime {args, prim, return} =>
            if not (isBlockKept return) then Transfer.Bug
            else Transfer.Runtime {args = args, prim = prim, return = return}
       | Transfer.Spork {spid, cont, spwn} =>
            if not (isBlockKept cont) orelse not (isBlockKept spwn) then Transfer.Bug
            else t
       | Transfer.Spoin {spid, seq, sync} =>
            if not (isBlockKept seq) orelse not (isBlockKept sync) then Transfer.Bug
            else t
       | Transfer.Raise _ => t
       | Transfer.Return _ => t

   fun filterBlock (b: Block.t): Block.t option = let
      val Block.T {args, label, statements, transfer} = b
   in
      if not (isBlockKept label) then NONE
      else
         let
            val args' = filterVectorByIndices (args, getBlockKeptIndices label)
            val statements' = Vector.keepAll (statements, keepStmt)
            val transfer' = filterTransfer transfer
         in
            SOME (Block.T {args = args',
                           label = label,
                           statements = statements',
                           transfer = transfer'})
         end
   end

   fun filterFunction (f: Function.t): Function.t option = let
      val name = Function.name f
   in
      if not (isFuncKept name) then NONE
      else
         let
            val {args, blocks, inline, raises, returns, start, ...} = Function.dest f
            val args' = filterVectorByIndices (args, getFuncKeptIndices name)
            val blocks' = Vector.keepAllMap (blocks, filterBlock)
         in
            SOME (Function.new {args = args',
                                blocks = blocks',
                                inline = inline,
                                name = name,
                                raises = raises,
                                returns = returns,
                                start = start})
         end
   end

   val functions' = List.keepAllMap (functions, filterFunction)
   val globals' = Vector.keepAll (globals, keepStmt)
   val datatypes' = Vector.keepAll (datatypes, fn Datatype.T {tycon, ...} => isTyconKept tycon)

   (* Cleanup properties *)
   val _ = destroyDef ()
   val _ = destroyCallSites ()
   val _ = destroyReturns ()
   val _ = destroyRaises ()
   val _ = destroyPredecessors ()
   val _ = destroyUses ()
   val _ = destroyBlockFunc ()
   val _ = destroyFuncToFunction ()
   val _ = destroyLabelToBlock ()

   val _ = destroyBlockKept ()
   val _ = destroyFuncKept ()
   val _ = destroyFuncKeptIndices ()
   val _ = destroyBlockKeptIndices ()
   val _ = destroyTyconKept ()
in
   Program.T {datatypes = datatypes',
              functions = functions',
              globals = globals',
              main = main}
end

fun transform p = p

end
