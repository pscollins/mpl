(* RUN: mpl-print-c %s > %t 2>&1
   RUN: ! grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a value from a tuple (elided by optimization).
 *)

val _ = let
    val t = (1, Array.sub (Array.fromList [2], 0))
    val v = #1 t
    val v' = MLton.Trace.noHeap v
in
    print (Int.toString v')
end
