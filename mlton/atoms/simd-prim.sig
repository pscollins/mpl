signature SIMD_PRIM = sig
    (* Binary operations with codegen support *)
    datatype binop =
             Add
             | Mul
             | Sub

    (* String representation of each binop type: this determines the `prim` name *)
    val binOpName: binop -> string
end
