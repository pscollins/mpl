(* RUN: mpl-print-c -disable-pass DeepFlatten %s > %t 2>&1 || true
   RUN: grep 'Found forbidden tuple operations' %t

   Test `Trace_noTuple` on components of an (real * real) array` element, with
   DeepFlatten disabled
 *)

val _ = let
    val arr = Array.fromList [(1.0, 2.0), (3.0, 4.0)]
    val p = Array.sub (arr, 0)
    val x = #1 p
    val y = #2 p
    val x' = MLton.Trace.noTuple x
    val y' = MLton.Trace.noTiple y
in
    print (Real.toString (x' + y'))
end
