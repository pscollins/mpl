(* RUN: mpl-print-c %s > %t 2>&1
   RUN: grep -v 'Found forbidden tuple operations' %t

   Test `Trace_noTuple` on components of an (real * real) array` element

   Verifies that `DeepFlatten` works as intended
 *)

val _ = let
    val arr = Array.fromList [(1.0, 2.0), (3.0, 4.0)]
    val p = Array.sub (arr, 0)
    val x = #1 p
    val y = #2 p
    val x' = MLton.Trace.noTuple x
    val y' = MLton.Trace.noTuple y
in
    print (Real.toString (x' + y'))
end
