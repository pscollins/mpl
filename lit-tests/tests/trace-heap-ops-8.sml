(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a value passed through a constructor (heap round-trip).
   Should fail because it involves a heap load.
 *)

datatype t = T of int

val _ = let
    val arr = Array.fromList [1, 2]
    val v = Array.sub (arr, 0)
    val x = T v
    val (T y) = x
    val z = MLton.Trace.noHeap y
in
    print (Int.toString z)
end
