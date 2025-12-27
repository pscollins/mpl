structure Float32x8 = MLton.Float32x8

structure Real = Real32
structure Random = MLton.Random

type vec = Real.real array

type testCase = {
  lhs: int list,
  rhs: int list,
  expected: int
}

fun intListToVec (xs: int list) =
  Array.fromList (List.map Real.fromInt xs)

fun arrToList (arr: 'a array): 'a list = Array.foldr (op ::) [] arr

fun evalCaseWith (dotF: vec * vec -> Real.real) (pfx: string) (tc: testCase) = let
  val actual: Real.real = dotF (intListToVec (#lhs tc), intListToVec (#rhs tc))
in
  assertRealEqual pfx (Real.fromInt (#expected tc)) actual
end

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

val _ = let
  val evalCase =
      evalCaseWith scalarDot "test scalar"
  val cases = [
    {lhs = [1], rhs = [1], expected = 1},
    {lhs = [2], rhs = [1], expected = 2},
    {lhs = [1, 1], rhs = [1, 1], expected = 2},
    {lhs = [2, 1], rhs = [2, 1], expected = 5}
  ]
in
  List.app evalCase cases
end

val _ = let
  fun mkListWithLen (len: int) (value: int) =
      List.tabulate (len, (fn _ => value))
  val mkList = mkListWithLen kNumLanes
  val evalCase =
      evalCaseWith simdDot "test SIMD"
  val cases = [
    {lhs = mkList 1,
     rhs = mkList 1,
     expected = 8},
    {lhs = mkList 2,
     rhs = mkList 1,
     expected = 16},
    {lhs = mkListWithLen (kNumLanes * 2) 1,
     rhs = mkListWithLen (kNumLanes * 2) 2,
     expected = 32},
    {lhs = (mkList 1) @ (mkList 2),
     rhs = (mkList 2) @ (mkList 1),
     expected = 32},
    {lhs = mkListWithLen (kNumLanes * 4) 2,
     rhs = mkListWithLen (kNumLanes * 4) 1,
     expected = 64}
  ]
in
  List.app evalCase cases
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
    this as (sign, magnitude), so instead we generate in the range (-max, +max)
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

val _ = let
  val kLen = 512
  val kMax = 4
  val kTol: real = 0.001
  fun evalCase (seed: int) = let
    val inputs = genRandomVecs (kLen, kMax) seed
    val want = scalarDot inputs
    val got = simdDot inputs
    val pfx = String.concat ["vec test vs reference (seed=", Int.toString seed, ")"]
  in
    assertRealNear kTol pfx want got
  end
in
  List.app evalCase (iota 1000 1100)
end

val _ = summarizeRun()
