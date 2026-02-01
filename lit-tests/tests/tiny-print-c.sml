(* RUN: mpl-print-c %s > %t

   Test for `mpl-print-c`: verify that we can find a constant in the generated C

   RUN: grep 123456789 %t
   RUN: grep Stdio_print %t
 *)

val _ = let
    val kConst = 123456789;
in
    print (Int.toString kConst)
end
