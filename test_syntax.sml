datatype t = Con of int vector
val c = Con (Vector.fromList [1, 2])
val _ = case c of
    Con of cons => ()
