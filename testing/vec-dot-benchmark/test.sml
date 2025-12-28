(* Duplicating these aliases intentionally because I find them hard to follow *)
structure Float32x8 = MLton.Float32x8

structure Real = Real32
structure Random = MLton.Random

val kIters = (Word.toInt (Word.<< (0w1, 0w5))) - 1
val kMax = 1

fun keep x = x

fun evalBenchmark (name: string, dotF: vec * vec -> Real.real)
                  (seed: int, length: int) = let
  val msgParts = [name, "(length=", Int.toString length,
                  ", iters=", Int.toString kIters,
                  ", seed=", Int.toString seed, ")"]
  val inputs = genRandomVecs (length, kMax) seed
  fun doIter() = keep (dotF inputs)
  val result = collectTiming kIters doIter
  val summary = calculateSummary (String.concat msgParts, result)
  val _ = printSummary summary
in
  #resultsHash result
end

fun evalBenchmarkPair (arg: int * int) = let
  val scalarResult = evalBenchmark ("scalar", scalarDot) arg
  val simdResult = evalBenchmark ("simd", simdDot) arg
in
  (* Don't expect equal hashes because of rounding differences *)
  ()
end


val _ = let
  val kSeed = 1234567
  val lengths = [
    1024,
    2048,
    4096
  ]
  fun evalCase (length: int) = evalBenchmarkPair (kSeed, length)
in
  List.app evalCase lengths
end
