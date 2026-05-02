(* RUN: mpl-compile -keep-pass inlineTrace %s %t || true

   TODO(pscollins): Remove the ` || true` when codegen works

   Test that the sourceMark is inlined

   Non-inlined version should show up in `.pre`
   RUN: grep    'sourceMark_0 "mark1"' %t/*inlineTrace.pre.core-ml
   RUN: grep    'sourceMark_0 "mark2"' %t/*inlineTrace.pre.core-ml

   Non-inlined version should be gone in `.post`
   RUN: ! grep 'sourceMark_0 "mark1"' %t/*inlineTrace.post.core-ml
   RUN: ! grep 'sourceMark_0 "mark2"' %t/*inlineTrace.post.core-ml

   Inlined version should not appear in `.pre`
   RUN: ! grep 'Trace_sourceMark "mark1"' %t/*inlineTrace.pre.core-ml
   RUN: ! grep 'Trace_sourceMark "mark2"' %t/*inlineTrace.pre.core-ml

   Inlined version should appear in `.post`
   RUN: grep 'Trace_sourceMark ("mark1")' %t/*inlineTrace.post.core-ml
   RUN: grep 'Trace_sourceMark ("mark2")' %t/*inlineTrace.post.core-ml
 *)

val _ = let
    val kConst = 123456789
    val m1 = MLton.Trace.sourceMark "mark1"
    val kConst2 = kConst + 1
    val m2 = MLton.Trace.sourceMark "mark2"
in
    print (Int.toString kConst2)
end
