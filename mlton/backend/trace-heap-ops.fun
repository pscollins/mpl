functor TraceHeapOps (S: TRACE_HEAP_OPS_STRUCTS): TRACE_HEAP_OPS =
struct

open S

fun (p: Program.t, pred: Statement.t -> bool): Statement.t list = []

fun transform (p: Program.t): Program.t = let
   val _ = print "CALLED PASS!\n"
in
   p
end

end
