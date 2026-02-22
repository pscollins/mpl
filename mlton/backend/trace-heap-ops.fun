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

fun transform (p: Program.t): Program.t = let
   val _ = print "CALLED PASS!\n"
in
   p
end

end
