(* RUN: mpl-print-c %s > %t 2>&1 || true
   RUN: grep 'Ssa.TypeCheck.primApp' %t

   Verify that we can't apply noTuple to a tuple type: it prevents flattening
   and leads to uninteresting errors

 *)

val _ = let
    val (x1, x2) = MLton.Trace.noTuple (1, 2)
in
    print (Int.toString (x1 + x2))
end
