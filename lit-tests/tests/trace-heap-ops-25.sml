(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Missing .dst. for Trace_{noHeap,heapOk}' %t

   Test `Trace_noHeap` on an ignored result.

   CRITICAL BUG: Currently, the compiler crashes if the result of a
   `Trace_noHeap` or `Trace_heapOK` call is ignored (e.g., bound to `_`).

   1. SSA-to-RSSA conversion sees the unused result and generates a
      `PrimApp` with `dst = NONE`.
   2. `Rssa.typeCheck` formerly crashed because `RepType.checkPrimApp`
      expected the primapp to always return its argument type. (FIXED)
   3. `TraceHeapOps.transform` now crashes because it tries to elide the
      `Trace_noHeap` into a `Bind` but `Bind` REQUIRES a destination variable.
      It should instead elide to nothing (delete the statement) if `dst = NONE`.
 *)

val _ = let
    val x = 1
    val _ = MLton.Trace.noHeap x
in
    print (Int.toString x)
end
