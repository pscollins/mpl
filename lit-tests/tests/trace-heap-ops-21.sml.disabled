(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a projection from an `(int * int) array` element.
   This test distinguishes between cases where `DeepFlatten` kicks in for the
   array and where it does not.

   If `DeepFlatten` flattens the `(int * int) array` into two `int` arrays,
   then `Array.sub` returns a virtual tuple of two `int`s. The `heapOK`
   operation then applies to these components (if `DeepFlatten` is smart).
   The projection `#1 p` then becomes one of these `heapOK`ed components,
   which is not a forbidden heap operation.

   If `DeepFlatten` does NOT kick in (the current behavior), then `p` is a 
   pointer to a heap-allocated pair. `heapOK p` makes `p` itself "good",
   but the projection `x = #1 p` is implemented as a heap load (`Offset`),
   which is a forbidden operation. Thus `MLton.Trace.noHeap x` will fail.
 *)

val _ = let
    val arr = Array.fromList [(1, 2), (3, 4)]
    val p = MLton.Trace.heapOK (Array.sub (arr, 0))
    val x = #1 p
    val _ = MLton.Trace.noHeap x
in
    print (Int.toString x)
end
