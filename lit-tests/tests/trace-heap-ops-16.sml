(* RUN: mpl-print-c %s > %t 2>&1
   RUN: ! grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` o `Trace_heapOK` always succeeds.
 *)

val _ = let
    val arr = Array.fromList [1, 2, 3]
    val x = MLton.Trace.noHeap (MLton.Trace.heapOK (Array.sub (arr, 0)))
in
    print (Int.toString x)
end
