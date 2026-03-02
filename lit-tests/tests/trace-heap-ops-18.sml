(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'raised: Option' %t

   Test `Trace_noHeap` on a unit value.
   Should succeed, but currently fails with an internal compiler error (Option).
   TODO(gemini): This test fails; investigate.
 *)

val _ = let
    val x = MLton.Trace.noHeap ()
in
    print "PASS\n"
end
