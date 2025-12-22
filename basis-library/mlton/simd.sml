structure MLtonFloat32x8 :> MLTON_SIMD_TYPE
          where type scalar = Real32.real
= struct
structure Prim = Primitive.MLton.Simd

type scalar = Real32.real
type scalarVec = scalar Vector.vector
type scalarArr = scalar Array.array
type t = Prim.float8Reg

val numLanes = 8

fun fromVec (vec, idx) =
   (* TODO(pscollins): Support arbitrary indices *)
   if idx = 0 then
    Prim.float32x8_load vec
  else
    raise Fail "bad index"

fun toVec xs = let
  (* TODO(pscollins): Primitive.Array.unsafeAlloc *)
  val arr = Array.array (numLanes, 0.0)
  val _ = Prim.float32x8_store (xs, arr)
in
  Array.vector arr
end

fun add (xs: t) (ys: t): t = Prim.float32x8_add (xs, ys)
end
