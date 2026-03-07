(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a projection from a tuple that is `heapOK`ed.
   This is the non-array version of the DeepFlatten test.
 *)

val _ = let
    val p = (1, 2)
    val p' = MLton.Trace.heapOK p
    val x = #1 p'
    val _ = MLton.Trace.noHeap x
in
    print (Int.toString x)
end
