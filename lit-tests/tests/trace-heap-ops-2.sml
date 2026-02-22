(* RUN: mpl-compile -keep-pass traceHeapOps %s %t

   Test `Trace_noHeap` success for chained applications.

   No IR assertions here -- just making sure that it doesn't trigger the compile
   failure.
 *)

val _ = let
    val x = MLton.Trace.noHeap 1
    val y = MLton.Trace.noHeap 2
    val z = MLton.Trace.noHeap (x + y)
in
    print (Int.toString z)
end
