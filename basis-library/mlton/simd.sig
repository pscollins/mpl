signature MLTON_SIMD_TYPE =
sig
    type scalar
    type scalarVec
    type t

    val fromVec: (scalarVec * int) -> t
    val toVec: t -> scalarVec
    val add: t -> t -> t
end
