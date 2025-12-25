structure Float32x8 = MLton.Float32x8

structure Real = Real32

type vector = Real.real array

type testCase = {
  lhs: int list
  rhs: int list
  expected: int
}

fun intListToVec (xs: int list) = 
  Array.fromList (List.map (Real.fromInt xs))

fun arrToList = Array.foldr (op ::) []

fun evalCaseWith (dotF: vector * vector -> vector) (pfx: string) (tc: testCase) = let
  val actual = dotF (intListToVec tc.lhs, intListToVec tc.rhs) 
in
  assertRealEqual pfx (Real.fromInt tc.expected) actual
end
  
fun assert (cond: bool) (msg: string) =
  if not cond then raise Fail ("Assertion failure: " ^ msg)
  else ()

fun scalarDot (lhs: vector, rhs: vector): Real32.real =
  let lengthOk = (Array.length lhs) == (Array.length rhs)
  val _ = assert lengthOk "length mismatch"
  (* sum += lhs[idx] * rhs[idx] *)
  fun add (idx, rhsEl, sum) = let
    val lhsEl = Array.sub lhs idx
  in
    Real.+ sum (Real.* rhsEl lhsEl)
in
  Array.foldli add 0.0 rhs
end

val _ = let
  fun evalCase tc = 
    evalCaseWith scalarDot "test scalar"
  in
  val cases = [
    {lhs = [1], rhs = [1], expected = [1]},
    {lhs = [2], rhs = [1], expected = [2]},
    {lhs = [1, 1], rhs = [1, 1], expected = [2]},
    {lhs = [2, 1], rhs = [2, 1], expected = [5]},
  ]
in
  List.app evalCase cases
end

val _ = summarizeRun()
