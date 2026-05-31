(* RUN: mpl-compile \
   RUN:    -keep-pass 'shallowFlatten.*' \
   RUN:    -shallow-flatten-policy maxWidth:2 \
   RUN:    %s.mlb %t
 
   Test that all supported Array/Vector primitives are flattened.

   RUN: ! grep -F 'Array_alloc[(real64, real64) tuple]'  %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Array_length[(real64, real64) tuple]' %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Array_sub[(real64, real64) tuple]'    %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Array_update[(real64, real64) tuple]' %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Array_toVector[(real64, real64) tuple]' %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Array_toArray[(real64, real64) tuple]' %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Array_uninit[(real64, real64) tuple]' %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Vector_length[(real64, real64) tuple]' %t/*shallowFlatten*.post.ssa
   RUN: ! grep -F 'Vector_sub[(real64, real64) tuple]'    %t/*shallowFlatten*.post.ssa

   RUN: grep -F  'Array_alloc[real64]'  %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Array_length[real64]' %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Array_sub[real64]'    %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Array_update[real64]' %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Array_toVector[real64]' %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Array_toArray[real64]' %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Array_uninit[real64]' %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Vector_length[real64]' %t/*shallowFlatten*.post.ssa
   RUN: grep -F 'Vector_sub[real64]'    %t/*shallowFlatten*.post.ssa
 *)

val alloc = _prim "Array_alloc": Word64.word -> (real * real) array;
val allocRaw = _prim "Array_allocRaw": Word64.word -> (real * real) array;
val sub = _prim "Array_sub": (real * real) array * Word64.word -> (real * real);
val update = _prim "Array_update": (real * real) array * Word64.word * (real * real) -> unit;
val length = _prim "Array_length": (real * real) array -> Word64.word;
val toVector = _prim "Array_toVector": (real * real) array -> (real * real) vector;
val toArray = _prim "Array_toArray": (real * real) array -> (real * real) array;
val uninit = _prim "Array_uninit": (real * real) array * Word64.word -> unit;
val uninitIsNop = _prim "Array_uninitIsNop": (real * real) array -> bool;

val v_sub = _prim "Vector_sub": (real * real) vector * Word64.word -> (real * real);
val v_length = _prim "Vector_length": (real * real) vector -> Word64.word;

val size = 0w10: Word64.word

(* 1. alloc & update *)
val a1 = alloc size
val _ = update (a1, 0w0, (1.0, 2.0))

(* 2. length & sub *)
val len1 = length a1
val (x1, y1) = sub (a1, 0w0)

(* 3. toVector, v_length, v_sub *)
val vec = toVector a1
val len2 = v_length vec
val (x2, y2) = v_sub (vec, 0w0)

(* 4. allocRaw, uninit, uninitIsNop, toArray *)
val a2 = allocRaw size
val _ = uninit (a2, 0w0)
val nop = uninitIsNop a2
val a3 = toArray a2

val (x3, y3) = sub (a3, 0w0)

(* print to keep alive *)
val _ = print (Real.toString x1 ^ " " ^ Real.toString y1 ^ " " ^
               Real.toString x2 ^ " " ^ Real.toString y2 ^ " " ^
               Real.toString x3 ^ " " ^ Real.toString y3 ^ " " ^
               Word64.toString len1 ^ " " ^ Word64.toString len2 ^ " " ^
               Bool.toString nop ^ "\n")
