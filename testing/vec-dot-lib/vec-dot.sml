(* TODO(pscollins): Ideally, this should probably be wrapped in a structure so
that we can import it without polluting the global namespace, but this is OK for
now.*)
structure Float32x8 = MLton.Float32x8

structure Real = Real32
structure Random = MLton.Random

type vec = Real.real array

fun assert (cond: bool) (msg: string) =
  if not cond then raise Fail ("Assertion failure: " ^ msg)
  else ()

fun getLength (lhs: vec, rhs: vec): int = let
  val lengthOk = (Array.length lhs) = (Array.length rhs)
  val _ = assert lengthOk "length mismatch"
in
  Array.length lhs
end

fun scalarDot (lhs: vec, rhs: vec): Real32.real = let
  val _ = getLength (lhs, rhs)
  (* sum += lhs[idx] * rhs[idx] *)
  fun add (idx: int, rhsEl: Real.real, sum: Real.real): Real.real = let
    val lhsEl = Array.sub (lhs, idx)
  in
    Real.+ (sum, (Real.* (rhsEl, lhsEl)))
  end
  val init: Real.real = 0.0
in
  Array.foldli add init rhs
end

val kNumLanes = 8

fun getZero(): Float32x8.t = let
  (* TODO(pscollins): We should have a broadcast primitive *)
  val zeroArr =
      Array.array (kNumLanes, 0.0)
in
  Float32x8.fromVec (Array.vector zeroArr, 0)
end


fun simdDot (lhs: vec, rhs: vec): Real32.real = let
  val len = getLength (lhs, rhs)
  val _ = assert ((len mod kNumLanes) = 0)
  fun doAdd (idx, acc: Float32x8.t): Float32x8.t = let
    fun addToAcc () = let
      val lhs' = Float32x8.fromVec (Array.vector lhs, idx)
      val rhs' = Float32x8.fromVec (Array.vector rhs, idx)
      val sum = Float32x8.mul lhs' rhs'
    in
      doAdd (idx + kNumLanes, Float32x8.add acc sum)
    end
  in
    if idx >= len then acc else addToAcc()
  end
in
  Float32x8.reduceAdd (doAdd (0, getZero()))
end

(* Generates an int in the range [0, max). We would ideally use the version from
`lib/mlton/basic/random.{sig,sml}`, but I can't get the dependency to work *)
fun genInt (max: int) = let
  val max' = Word.fromInt max
  val w = Random.rand()
  val result = Word.mod (w, max')
in
  Word.toInt result
end

fun genRandomVecs (len: int, max: int) (seed: int): (vec * vec) = let
  (* set a seed per call for reproducibility/debugging *)
  val _ = Random.srand (Word.fromInt seed)
  val kScale = Word.toInt (Word.<< (Word.fromInt 1, Word.fromInt 15))
  fun applyScale (n: int) = (Real.fromInt n) / (Real.fromInt kScale)
  fun genNum () = let
    (* Can't generate floats directly, so generate in the range scaled up by
      kScale and divide

    There is some weirdness in the implementation of `rand()` such that we
    deterministically swtich betwen all-negative and all-positive if we generate
    this as (sign, magnitude), so instead we generate in the range [0, +max]
    and subtract *)
    val scaledMax = max * kScale
    val unscaled = (genInt (scaledMax * 2 + 1)) - scaledMax
  in
    applyScale unscaled
  end
  fun genVec() = Array.tabulate (len, (fn _ => genNum()))
in
  (genVec(), genVec())
end

val _ = summarizeRun()
