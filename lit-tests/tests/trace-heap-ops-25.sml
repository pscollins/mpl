(* RUN: mpl-compile -keep-pass traceHeapOps %s %t

  Test that we emit the appropriate dummy binding

  RUN: egrep '_: Bits0 = Trace_noHeap \(global_' %t/*traceHeapOps.pre.rssa
  RUN: egrep 'dummy_.*: Word32 = global_' %t/*traceHeapOps.post.rssa
 *)

val _ = let
    val x = 1
    val _ = MLton.Trace.noHeap x
in
    print (Int.toString x)
end
