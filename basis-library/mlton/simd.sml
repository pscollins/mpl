structure MLtonFloat32x8 :> MLTON_SIMD_TYPE
          where type scalar = Real32.real
= struct

type scalar = Real32.real
type scalarVec = scalar Vector.vector
type t = scalarVec

val numLanes = 8

fun fromVec (vec, idx) =
    (VectorSlice.vector o VectorSlice.slice) (vec, idx, SOME numLanes)

fun toVec xs = xs

fun add (xs: t) (ys: t): t = let
    (* TODO(pscollins): Primitive.Array.unsafeAlloc *)
    val arr = Array.array (numLanes, 0.0)
    (* TODO(pscollins): Float32x8_addArr (xs, ys, arr) *)
    fun setElement (idx, unused): scalar = let
        fun getIdx vec = Vector.sub (vec, idx)
    in
        Real32.+ (getIdx xs, getIdx ys)
    end
    val _ = Array.modifyi setElement arr
in
    Array.vector arr
end
end
