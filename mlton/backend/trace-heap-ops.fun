functor TraceHeapOps (S: TRACE_HEAP_OPS_STRUCTS): TRACE_HEAP_OPS =
struct

open S

structure VarSet = UnorderedSet (Var)

fun filterStatements
        (p: Program.t, pred: Statement.t -> bool): Statement.t list = let
   val Program.T {functions, main, ...} = p
   val allFuncs = List.cons (main, functions)
   fun filterStatement (s: Statement.t): Statement.t option =
       if pred s then SOME s
       else NONE
   fun filterBlock (Block.T {statements, ...}): Statement.t list =
       Vector.toListKeepAllMap (statements, filterStatement)
   fun filterFunc (f: Function.t): Statement.t list =
       List.concat (Vector.toListMap
                        (Function.blocks f, filterBlock))
in
   List.concatMap (allFuncs, filterFunc)
end

fun mapStatements
        (p: Program.t, rewrite: Statement.t -> Statement.t option): Program.t = let
   (* TODO(pscollins): Can we avoid the copies here? *)
   val Program.T {functions, handlesSignals, main, objectTypes, profileInfo,
                  statics} = p
   fun rewriteStatement (s: Statement.t) =
       case rewrite s of
           SOME s' => s'
         | NONE => s
   fun rewriteStatements (stmts: Statement.t vector) =
       Vector.map (stmts, rewriteStatement)
   fun rewriteBlock (b: Block.t) = let
      val Block.T {args, kind, label, statements, transfer} = b
   in
      Block.T {args = args,
               kind = kind,
               label = label,
               statements = rewriteStatements statements,
               transfer = transfer}
   end
   fun rewriteBlocks (bs: Block.t vector) = Vector.map (bs, rewriteBlock)
   fun rewriteFunc (f: Function.t) = let
      val {args, blocks, name, raises, returns, start} = Function.dest f
   in
      Function.new {args = args,
                    blocks = rewriteBlocks blocks,
                    name = name,
                    raises = raises,
                    returns = returns,
                    start = start}
   end
in
   Program.T {functions = List.map (functions, rewriteFunc),
              handlesSignals = handlesSignals,
              main = rewriteFunc main,
              objectTypes = objectTypes,
              profileInfo = profileInfo,
              statics = statics}
end

fun foldStatements (p: Program.t, init: 'a, f: Statement.t * 'a -> 'a): 'a = let
   fun constTrue x = true
   (* TODO(pscollins): Consider a more efficient implementation -- for now, for
   simplicity, we'll just reuse `filterStatements` to flatten the program into a
   `Statement.t list` *)
   val stmts = filterStatements (p, constTrue)
in
   List.fold (stmts, init, f)
end

fun statementsToString (stmts: Statement.t list): string =
    Layout.toString (Layout.align (List.map (stmts, Statement.layout)))

fun getUniqueArg (args: Operand.t vector): Operand.t =
    if Vector.length args = 1
    then Vector.first args
    else Error.bug "Bad argument count for Trace_noHeap"

fun isForbiddenHeapOperand (arg: Operand.t): bool =
    case arg of
           Operand.Cast _ => false
         | Operand.Const _ => false
         | Operand.Var _ => false
         | _ => true

fun isForbiddenTupleOperand (arg: Operand.t): bool =
    case arg of
           Operand.Offset _ => true
         | _ => false


fun collectVarsMatchingSrcPred (srcPred: Operand.t -> bool)
                               (p: Program.t): VarSet.t = let
   fun updateSet (stmt: Statement.t, set: VarSet.t) =
       case stmt of
           Statement.Bind {dst = (dstVar, _), src, ...} =>
           if srcPred src then
              VarSet.add (set, dstVar)
           else set
        |  _ => set
in
   foldStatements (p, VarSet.empty, updateSet)
end

fun collectForbiddenHeapVars (p: Program.t): VarSet.t =
    collectVarsMatchingSrcPred isForbiddenHeapOperand p

fun collectForbiddenTupleVars (p: Program.t): VarSet.t =
    collectVarsMatchingSrcPred isForbiddenTupleOperand p

fun isForbiddenOp (operandPred: Operand.t -> bool, wantPrim: Type.t Prim.t)
                  (vs: VarSet.t) (s: Statement.t): bool = let
   fun isForbidden arg =
       case arg of
             Operand.Var {var, ...} => VarSet.contains (vs, var)
           | _ => operandPred arg
in
    case s of
        Statement.PrimApp {args, dst, prim} =>
        if Prim.equals (prim, wantPrim) then
           isForbidden (getUniqueArg args)
        else false
      | _ => false
end

fun isForbiddenHeapOp (vs: VarSet.t) (s: Statement.t): bool =
    isForbiddenOp (isForbiddenHeapOperand, Prim.Trace_noHeap)
                  vs s

fun isForbiddenTupleOp (vs: VarSet.t) (s: Statement.t): bool =
    isForbiddenOp (isForbiddenTupleOperand, Prim.Trace_noTuple)
                  vs s

local
   fun buildDst (arg: Operand.t,
                 dst: (Var.t * Type.t) option): Var.t * Type.t = let
      fun buildDummyDst () = let
         val newVar = Var.newString "dummy"
      in
         (newVar, Operand.ty arg)
      end
   in
      case dst of
          (* When the prim result has a user, we get a non-NONE `dst` and we
           elide the prim by binding the prim argument to it *)
          SOME dst' => dst'
        (* Otherwise, we build a dummy binding to a new variable of the
            appropriate type *)
        | NONE  => buildDummyDst()
   end
   fun buildBind (arg: Operand.t, dst: (Var.t * Type.t) option) =
       Statement.Bind {dst = buildDst (arg, dst),
                       pinned = false,
                       src = arg}
   fun buildBindFromStmt (Statement.PrimApp {args, dst, ...}) =
       SOME (buildBind (getUniqueArg args, dst))
     | buildBindFromStmt _ = Error.bug "unreachable"
in
fun maybeElideNoHeap (s: Statement.t): Statement.t option =
   case s of
       Statement.PrimApp {prim = Prim.Trace_noHeap, ...} =>
       buildBindFromStmt s
     | _ => NONE

fun maybeElideHeapOk (s: Statement.t): Statement.t option =
    case s of
        Statement.PrimApp {prim = Prim.Trace_heapOK, ...} =>
        buildBindFromStmt s
      | _ => NONE

fun maybeElideNoTuple (s: Statement.t): Statement.t option =
   case s of
       Statement.PrimApp {prim = Prim.Trace_noTuple, ...} =>
       buildBindFromStmt s
    | _ => NONE
end

fun transform (p: Program.t): Program.t = let
   val badHeapVars = collectForbiddenHeapVars p
   val badTupleVars = collectForbiddenTupleVars p
   val badHeapStmts = filterStatements (p, isForbiddenHeapOp badHeapVars)
   val badTupleStmts = filterStatements (p, isForbiddenTupleOp badTupleVars)
   fun doMaybeElide (preds, s, acc) =
       case (preds, acc) of
           (pred::preds', NONE) => doMaybeElide (preds', s, pred s)
         | _ => acc
   fun maybeElide (s: Statement.t): Statement.t option =
       doMaybeElide ([maybeElideNoHeap, maybeElideHeapOk, maybeElideNoTuple],
                     s, NONE)
   fun doRewrite (p: Program.t) =
       mapStatements (p, maybeElide)
in
   case (badHeapStmts, badTupleStmts)  of
       ([], []) => doRewrite p
     | (_, []) => Error.bug (concat ["Found forbidden heap operations: ",
                                     statementsToString badHeapStmts])
     | ([], _) => Error.bug (concat ["Found forbidden tuple operations: ",
                                     statementsToString badTupleStmts])
     | (_, _) => Error.bug (concat ["Found forbidden heap+tuple operations: ",
                                    statementsToString (badHeapStmts @ badTupleStmts)])

end

end
