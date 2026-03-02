(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a value from a closure environment (heap round-trip).
   Should fail because it involves a heap load (from the closure).
 *)

fun f v = let
    fun g () = MLton.Trace.noHeap v
in
    g ()
end

val _ = let
    val x = f (Array.sub (Array.fromList [1, 2], 0))
in
    print (Int.toString x)
end
