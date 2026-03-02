(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a value from a global ref.
   Should fail because it involves a heap load.
 *)

val r = ref 42
val _ = r := (Array.sub (Array.fromList [1, 2], 0))

val _ = let
    val x = MLton.Trace.noHeap (!r)
in
    print (Int.toString x)
end
