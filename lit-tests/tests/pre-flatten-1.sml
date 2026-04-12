

fun __inline_never__ doAdd (args: int * int) = let
   val (x, y) = args
in 
   x + y
end
    

val res1 = doAdd((1, 1))
val res2 = let
   val inputs = Array.array (1, (1, 1))
in
   doAdd (Array.sub (inputs, 1))
end

val _ = print (Int.toString (res1 + res2))
