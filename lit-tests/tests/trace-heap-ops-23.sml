(* RUN: mpl-print-c %s > %t 2>&1
   RUN: ! grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on components of a flattened array of pairs.
   This should succeed because components are individually heapOK'ed.
 *)

val _ = let
    val arr = Array.fromList [(1, 2), (3, 4)]
    val (x, y) = Array.sub (arr, 0)
    val x' = MLton.Trace.noHeap (MLton.Trace.heapOK x)
    val _ = print (Int.toString x')
in
    ()
end
