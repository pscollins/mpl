signature MLTON_SIMD_TYPE =
sig
    type scalar
    type scalarVec = scalar Vector.vector
    type t

    val fromVec: (scalarVec * int) -> t
    val toVec: t -> scalarVec
    val add: t -> t -> t
    val mul: t -> t -> t
    val reduceAdd: t -> scalar
end
