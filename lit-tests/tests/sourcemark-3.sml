(* RUN: mpl-print-c %s > %t || true

   Test that we can locate a `sourceMarkValue` in the generated C

   RUN: grep '// Diagnostic(Trace_staticSourceMarkValue:markZ (GP(121): Objptr (opt_25)))' %t
 *)

val _ = let
    val kX = 1
    val kY = 2
    val kZ = (kX, kY)
    val _ = MLton.Trace.sourceMarkValue (kZ, "markZ")
    val z = kX + kY
in
    print (Int.toString z)
end
