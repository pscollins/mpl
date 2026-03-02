(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Found forbidden heap operations' %t

   Test `Trace_noHeap` inside a loop with a heap load.
   Should fail.
 *)

val _ = let
    val arr = Array.fromList [1, 2, 3, 4, 5]
    fun loop i =
        if i < 0 then 0
        else let
            val v = Array.sub (arr, i)
            val v' = MLton.Trace.noHeap v
        in
            v' + loop (i - 1)
        end
in
    print (Int.toString (loop 4))
end
