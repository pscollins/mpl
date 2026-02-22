(* RUN: mpl-compile -keep-pass traceHeapOps %s %t

   Test `Trace_noHeap` success + elimination for `Const`

   PrimApp in `pre`, pure assign in `post`. We're careful not to match the
   generated identifiers, which are not deterministic

   RUN: egrep 'x_.*: Word32 = Trace_noHeap \(global_' %t/*traceHeapOps.pre.rssa
   RUN: egrep 'x_.*: Word32 = global_' %t/*traceHeapOps.post.rssa
 *)

val _ = let
    val kConst = 123456789
    val const = MLton.Trace.noHeap kConst
in
    print (Int.toString const)
end
