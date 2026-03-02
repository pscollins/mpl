(* RUN: mpl-print-c %s  > %t

   Test that we can waive the error with heapOK

   grep 'Found forbidden heap operations' %t
 *)

val _ = let
   val arr = Array.fromList [1, 2]
   val x = MLton.Trace.heapOK (Array.sub (arr, 0))
   val y = Array.sub (arr, 1)
   val z = (MLton.Trace.noHeap x) + y
in
    print (Int.toString z)
end
