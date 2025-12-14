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

fun add (xs: t) (ys: t): t = let
    fun addElement (idx, x: scalar): scalar = let
        val y: scalar = Vec.sub (ys, idx)
    in
        Real32.+ (x, y)
    end
in
    Vec.mapi addElement xs
end
end
