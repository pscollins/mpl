structure MLtonFloat32x8 :> MLTON_SIMD_TYPE
          where type scalar = Real32.real
= struct
structure Prim = Primitive.MLton.Simd

type scalar = Real32.real
type scalarVec = scalar Vector.vector
type scalarArr = scalar Array.array
type t = Prim.reg

val numLanes = 8

fun fromVec (vec, idx) =
  if idx = 0 then
    Prim.float32x8_load vec
  else
    raise Fail "bad index"
  end
    (*(VectorSlice.vector o VectorSlice.slice) (vec, idx, SOME numLanes)*)

(*fun toVec xs = xs*)
fun toVec xs = let
  val arr = Array.array (numLanes, 0.0)
  val _ = Prim.float32x8_store (xs, arr)
in
  arr
end

fun add (xs: t) (ys: t): t = Prim.float32x8_add (xs, ys)
(*
let
    (* TODO(pscollins): Primitive.Array.unsafeAlloc *)
    val arr = Array.array (numLanes, 0.0)
    val _ = Prim.float32x8_addArr (xs, ys, arr)
in
    Array.vector arr
end
end
*)
