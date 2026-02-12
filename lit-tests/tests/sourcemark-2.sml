(* RUN: mpl-print-c %s > %t

   Test that we can locate a `sourceMarkValue` in the generated C

   TODO(pscollins): add assertions onces this compiles successfully
 *)

val _ = let
    val kX = 1
    val kY = 2
    val _ = MLton.Trace.sourceMarkValue (kX, "markX")
    val _ = MLton.Trace.sourceMarkValue (kY, "markY")
    val z = kX + kY
in
    print (Int.toString z)
end
