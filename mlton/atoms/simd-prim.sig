signature SIMD_PRIM = sig
    (* Binary operations with codegen support *)
    datatype binop =
             (* Arithmetic operators *)
             Add
             | Mul
             | Sub
             (* Comparison operators *)
             | Min

    (* String representation of each binop type: this determines the `prim` name *)
    val binOpName: binop -> string

    (* Reduction operations *)
    datatype reductionop =
             ReduceAdd

    (* String representation of each reductionop type: this determines the
    `prim` name *)
    val reductionOpName: reductionop -> string
end
