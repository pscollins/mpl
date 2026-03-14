(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on components of an `(int * int) array` element
   loaded without any heap* assertions on the tuple itself.

   This test asserts that we can access elements of a tuple without a heap
   load, provided DeepFlatten made the access a non-heap operation.

   If DeepFlatten is NOT active, `x = #1 p` is an `Offset` (heap load).
   If DeepFlatten IS active, `x = #1 p` is just a `Bind` from a variable.

   TODO(pscollins): Currently this fails (as the expectation shows above)
   because flattening gives us

      arr = [1 2 3 4]
      x = arr[0]
      y = arr[1]

   Ideally we could fix it by putting a `heapOk` around the `p` load, but then
   the _prim would beak the flattening transformation.
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
