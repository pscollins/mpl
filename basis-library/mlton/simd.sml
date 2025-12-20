structure MLtonFloat32x8 :> MLTON_SIMD_TYPE
          where type scalar = Real32.real
= struct
structure Prim = Primitive.MLton.Simd

type scalar = Real32.real
type scalarVec = scalar Vector.vector
type scalarArr = scalar Array.array
type t = scalarVec

val numLanes = 8

fun fromVec (vec, idx) =
    (VectorSlice.vector o VectorSlice.slice) (vec, idx, SOME numLanes)

fun toVec xs = xs

fun add (xs: t) (ys: t): t = let
    (* TODO(pscollins): Primitive.Array.unsafeAlloc *)
    val arr = Array.array (numLanes, 0.0)
    val _ = Prim.float32x8_addArr (xs, ys, arr)
in
    Array.vector arr
end
end
