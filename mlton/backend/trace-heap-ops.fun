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

fun isForbiddenHeapOp (s: Statement.t): bool = let
   fun isForbiddenHeapArg (arg: Operand.t): bool =
       case arg of
           Operand.Cast _ => false
         | Operand.Const _ => false
         | Operand.Var _ => false
         | _ =>
           true
   fun isForbiddenHeapArgs (args: Operand.t vector): bool =
       if Vector.length args = 1
       then isForbiddenHeapArg (Vector.first args)
       else Error.bug "Bad argument count for Trace_noHeap"
in
   case s of
       Statement.PrimApp {args, dst, prim = Prim.Trace_noHeap} => isForbiddenHeapArgs args
    | _ => false
end

fun transform (p: Program.t): Program.t = let
   val _ = print "CALLED PASS!\n"
in
   p
end

end
