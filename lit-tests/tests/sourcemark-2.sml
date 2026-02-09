(* RUN: mpl-print-c %s > %t

   Test that we can locate a `sourceMark` in the generated C

   RUn: grep '// Diagnostic(Trace_staticSourceMark:mark1)' %t
   RUN: grep '// Diagnostic(Trace_staticSourceMark:mark2)' %t
 *)

val _ = let
    val kConst = 123456789
    val m1 = MLton.Trace.sourceMark "mark1"
    val kConst2 = kConst + 1
    val m2 = MLton.Trace.sourceMark "mark2"
in
    print (Int.toString kConst2)
end
