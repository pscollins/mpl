structure SimdPrim : SIMD_PRIM = struct

datatype binop =
         Add
       | Mul
       | Sub

fun binOpName (binop: binop): string =
    case binop of
        Add => "add"
     |  Mul => "mul"
     |  Sub => "sub"

end
