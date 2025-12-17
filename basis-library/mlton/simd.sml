structure MLtonFloat32x8 :> MLTON_SIMD_TYPE
          where type scalarVec = Real32Vector.vector
= struct
structure Vec = Real32Vector
structure Slice = Real32VectorSlice

type scalar = Vec.elem
type scalarVec = Vec.vector
type t = scalarVec

val numLanes = 8

fun fromVec (vec, idx) =
    (Slice.vector o Slice.slice) (vec, idx, SOME numLanes)

fun toVec xs = xs

structure Prim = Primitive.MLton.Simd
val doAdd: (Real32Array.array * Real32Array.array * Real32Array.array) -> unit = 
  Prim.Float32x8_addArr

fun add (xs: t) (ys: t): t = let
    (* TODO(pscollins): Primitive.Array.unsafeAlloc *)
    val arr = Real32Array.array (numLanes, 0.0)
    (* TODO(pscollins): Float32x8_addArr (xs, ys, arr) *)
    fun setElement (idx, unused): scalar = let
        fun getIdx vec = Vec.sub (vec, idx)
    in
        Real32.+ (getIdx xs, getIdx ys)
    end
    val _ = Real32Array.modifyi setElement arr
in
    Real32Array.vector arr
end
end
