(* RUN: mpl-print-c %s || true  > %t

   Test `Trace_noHeap` rejects a case where a heap load is necessary.

   grep 'Found forbidden heap operations' %t
 *)

val _ = let
   val arr = Array.fromList [1, 2]
   val x = MLton.Trace.noHeap (Array.sub (arr, 0))
   val y = MLton.Trace.noHeap (Array.sub (arr, 1))
   val z = MLton.Trace.noHeap (x + y)
in
    print (Int.toString z)
end
