(* Duplicating these aliases intentionally because I find them hard to follow *)
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
