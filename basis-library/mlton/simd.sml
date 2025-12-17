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
type arr = scalar array
val doAdd: (arr * arr * arr) -> unit = 
  Prim.float32x8_addArr

structure Arr = Array
fun mkEmpty(): scalar array =
  Arr.array (numLanes, 0.0)

fun toArr (xs: t): scalar array = let
  val arr = mkEmpty()
  fun setElement (idx, unused): scalar = Vec.sub (xs, idx)
  val _ = Arr.modifyi setElement arr
in
  arr
end

fun toRealVec (arr: scalar array) = let 
  fun getElement idx = Array.sub (arr, idx)
in 
  Vec.tabulate (numLanes, getElement)
end

fun add (xs: t) (ys: t): t = let
    (* TODO(pscollins): Primitive.Array.unsafeAlloc *)
    val arr = mkEmpty()
    val xsArr = toArr xs 
    val ysArr = toArr ys
    val _ = doAdd (xsArr, ysArr, arr) 
in
   toRealVec arr
end
 (*
    val _ = doAdd (x
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
*)
end
