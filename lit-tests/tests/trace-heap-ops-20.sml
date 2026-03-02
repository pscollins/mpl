(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` on a character loaded from an array.
   Should fail because it involves a heap load.
 *)

val _ = let
    val arr = Array.fromList [#"h", #"e", #"l", #"l", #"o"]
    val c = Array.sub (arr, 0)
    val c' = MLton.Trace.noHeap c
in
    print (Char.toString c' ^ "\n")
end
