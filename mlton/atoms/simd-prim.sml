structure SimdPrim : SIMD_PRIM = struct

datatype binop =
         Add
       | Mul
       | Sub
       | Min

fun binOpName (binop: binop): string =
    case binop of
        Add => "add"
     |  Mul => "mul"
     |  Sub => "sub"
     |  Min => "min"

datatype reductionop = ReduceAdd

fun reductionOpName (reductionop: reductionop): string =
    case reductionop of
        ReduceAdd => "reduce_add"

end
