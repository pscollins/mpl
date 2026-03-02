(* RUN: mpl-print-c %s > %t 2>&1
   RUN: ! grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a string constant.
   Should succeed.
 *)

val _ = let
    val s = "hello"
    val x = MLton.Trace.noHeap s
in
    print (x ^ "\n")
end
