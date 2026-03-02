(* RUN: mpl-print-c %s || true  > %t

   Test `Trace_noHeap` rejects a case where a heap load is necessary (and we can
   push it in the inner expression as expected)

   grep 'Found forbidden heap operations' %t
 *)

val _ = let
   val arr = Array.fromList [1, 2]
   val x = Array.sub (arr, 0)
   val y = Array.sub (arr, 1)
   val z = (MLton.Trace.noHeap x) + y
in
    print (Int.toString z)
end
