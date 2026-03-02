(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a value from a list (polymorphic sum).
   Should fail because list elements are loaded from the heap.
 *)

fun sum [] = 0
  | sum (x::xs) = (MLton.Trace.noHeap x) + sum xs

val _ = let
    val l = [1, 2, 3, 4, 5]
    val s = sum l
in
    print (Int.toString s)
end
