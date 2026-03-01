functor TraceHeapOps (S: TRACE_HEAP_OPS_STRUCTS): TRACE_HEAP_OPS =
struct

open S

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

fun foldStatements (p: Program.t, init: 'a, f: Statement.t * 'a -> 'a): 'a =
    raise Fail "error"


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

fun isForbiddenHeapOp (s: Statement.t): bool =
    case s of
        Statement.PrimApp {args, dst, prim = Prim.Trace_noHeap} =>
        isForbiddenHeapOperand (getUniqueArg args)
      | _ => false

local
   fun getDst (dst: (Var.t * Type.t) option): Var.t * Type.t =
       case dst of
           SOME dst' => dst'
         | _ => Error.bug "Missing `dst` for Trace_{noHeap,heapOk}"
   fun buildBind (arg: Operand.t, dst: (Var.t * Type.t) option) =
       Statement.Bind {dst = getDst dst,
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
end

fun transform (p: Program.t): Program.t = let
   val badStmts = filterStatements (p, isForbiddenHeapOp)
   fun maybeElide s =
       case maybeElideNoHeap s of
           NONE => maybeElideHeapOk s
         | res => res
   fun doRewrite (p: Program.t) =
       mapStatements (p, maybeElide)
in
   case badStmts of
       [] => doRewrite p
     | _ => Error.bug (concat ["Found forbidden heap operations: ",
                               statementsToString badStmts])
end

end
