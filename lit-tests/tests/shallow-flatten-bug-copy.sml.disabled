(* XFAIL: *
   RUN: mpl-compile \
   RUN:    -keep-pass 'shallowFlatten.*' \
   RUN:    -shallow-flatten-policy maxWidth:2 \
   RUN:    %s.mlb %t
 
   BUG REPORT:
   Compiling `Array.copy` on a tuple-array matching the policy (maxWidth:2)
   causes the compiler to crash with Option exception in shallow-flatten.fun
   because Array_copyArray is marked for flattening but not implemented
   in `maybeFlattenStatement`.
 *)

val n = List.length (CommandLine.arguments ()) + 10

val arr1: (real * real) array = Array.array (n, (1.0, 2.0))
val arr2: (real * real) array = Array.array (n, (0.0, 0.0))
val _ = Array.copy {src = arr1, dst = arr2, di = 0}

val (x, y) = Array.sub (arr2, 0)
val _ = print (Real.toString x ^ " " ^ Real.toString y ^ "\n")
