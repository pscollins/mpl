(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Rssa.typeCheck' %t

   Test `Trace_noHeap` on a ref cell (pointer).
   Currently fails with Rssa.typeCheck error.
 *)

val _ = let
    val r = ref 0
    val _ = MLton.Trace.noHeap r
in
    print "PASS\n"
end
