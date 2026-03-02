(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a function argument (no inlining).
   Should pass if not inlined.
 *)

fun f x = MLton.Trace.noHeap x

val _ = let
    val arr = Array.fromList [1, 2]
    val v = Array.sub (arr, 0)
in
    print (Int.toString (f v))
end
