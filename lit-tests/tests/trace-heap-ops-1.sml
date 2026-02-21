(* RUN: mpl-compile -keep-pass traceHeapOps %s %t || true

   Test `noHeap` validation+elimination

   TODO(pscollins): add assertions

   PrimApp in `pre`
   COM: grep 'Trace_staticSourceMark:mark1' %t/*emitDiagnostics.pre.machine
   COM: grep 'Trace_staticSourceMark:mark2' %t/*emitDiagnostics.pre.machine

   Diagnostic in `post`
   COM: grep 'Diagnostic(Trace_staticSourceMark:mark1 ())' %t/*emitDiagnostics.post.machine
   COM: grep 'Diagnostic(Trace_staticSourceMark:mark2 ())' %t/*emitDiagnostics.post.machine
 *)

val _ = let
    val kConst = 123456789
    val kConst' = MLton.Trace.noHeap (kConst)
in
    print (Int.toString kConst')
end
