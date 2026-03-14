(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on components of an (real * real) array` element
   loaded without any heap* assertions on the tuple itself.

   This follows `trace-heap-ops-26.sml`, testing the difference between handling
   `real` and `int`

   TODO(pscollins): Update the test below to use `real`.
 *)

val _ = let
    val arr = Array.fromList [(1, 2), (3, 4)]
    val p = Array.sub (arr, 0)
    val x = #1 p
    val y = #2 p
    val x' = MLton.Trace.noHeap x
    val y' = MLton.Trace.noHeap y
in
    print(Int.toString (x' + y'))
end
