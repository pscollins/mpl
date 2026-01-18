structure SimdPrim : SIMD_PRIM = struct

datatype binop =
         Add
       | Mul
       | Sub
       | Max
       | Min

fun binOpName (binop: binop): string =
    case binop of
        Add => "add"
     |  Mul => "mul"
     |  Sub => "sub"
     |  Max => "max"
     |  Min => "min"

datatype reductionop = ReduceAdd
                     | ReduceMax

fun reductionOpName (reductionop: reductionop): string =
    case reductionop of
        ReduceAdd => "reduce_add"
     |  ReduceMax => "reduce_max"

end
