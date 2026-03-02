(* RUN: mpl-print-c %s > %t 2>&1
   RUN: ! grep 'Found forbidden heap operations' %t

   Test `Trace_heapOK` propagates if optimization eliminates the local ref.
 *)

val _ = let
    val arr = Array.fromList [1, 2]
    val v = MLton.Trace.heapOK (Array.sub (arr, 0))
    val r = ref v
    val y = !r
    val z = MLton.Trace.noHeap y
in
    print (Int.toString z)
end
