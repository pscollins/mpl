val _ = let
    val _ = assertIntEqual "test int" 1 1
    val _ = assertIntEqual "test int2" 2 2
    val _ = let
        val _ = assertIntEqual "foo3" 1 0
        val _ = raise Fail "Did not raise expected exception!"
    in
        ()
    end
            handle FailedTest (msg) =>
                   print (String.concat ["Saw expected failure message: ", msg, "\n"])
in
    ()
end


val _ = let
  val _ = assertRealEqual "test real, true" 1.0 1.0
  val success = ref false
  val _ = let
    val _ = assertRealEqual "test real, false" 1.0 2.0
  in
    ()
  end
    handle FailedTest (msg) => (success := true)
  val _ = if not (!success) then raise Fail "negative test failed" else ()
in
  ()
end

val _ = let
    val idx = ref 0
    fun evalCase (lhs, rhs) = let
    in
        assertReal32ListNotEqual "test negative assertion for lists"
                                 (intsToReals lhs)
                                 (intsToReals rhs)
    end
    val cases = [
        ([1, 2], [3, 4]),
        ([1, 2], [1, 2, 3]),
        ([1, 2, 3, 4], [1, 2, 3]),
        ([], [1])
    ]
in
    List.app evalCase cases
end

val _ = let
    val idx = ref 0
    fun evalCase (lhs, rhs) = let
    in
        assertReal32ListEqual "test positive assertions for list"
                                 (intsToReals lhs)
                                 (intsToReals rhs)
    end
    val cases = [
        ([1, 2], [1, 2]),
        ([1, 2, 3], [1, 2, 3]),
        ([], [])
    ]
in
    List.app evalCase cases
end

val _ = let
    val idx = ref 0
    fun evalCase (lhs, rhs) = let
      val _ =
        assertReal32ListListEqual "test positive assertions for list list"
        lhs lhs
      val _ =
        assertReal32ListListNotEqual "test negative assertions for list list"
        lhs rhs
    in
      ()
    end
    val cases = [
        ([[1.0, 2.0],
          [3.0, 4.0]],

          [[3.0, 2.0],
           [3.0, 4.0]])
    ]
in
    List.app evalCase cases
end


val _ = let
    val idx = ref 0
    fun evalCase (lhs, rhs) = let
      val _ =
        assertIntListEqual "test positive assertions for int list"
        lhs lhs
      val _ =
        assertIntListNotEqual "test negative assertions for int list"
        lhs rhs
    in
      ()
    end
    val cases = [
        ([1, 2], [3, 4])
    ]
in
  List.app evalCase cases
end

exception TestException
val _ = let
  fun f() = raise TestException
  val _ = assertRaises "positive test" f "TestException"
  val _ = assertRaises "catches mismatch"
                       (fn () => assertRaises "positive test" f "DifferentException")
                       "FailedTest"
  fun g () = ()
  val _ = assertRaises "catches no exception"
                       (fn () => assertRaises "positive test" g "TestException")
                       "FailedTest"
in
  ()
end

fun round (r: real) = Real32.fromLarge IEEEReal.TO_NEAREST r

val _ = let
  val asserter = assertRealNear 0.1
  val kSmall = round 1.0
  val kLarge = round 1.01
  val _ = asserter "test close1" kSmall kLarge
  val _ = asserter "test close2" kLarge kSmall
  val _ = let
    fun f() = asserter "test far" 1.0 2.0
  in
    assertRaises "assertNear negative test" f "FailedTest"
  end
in
  ()
end

val _ = let
  fun evalCase (start, n, expected) = let
    val got = iota start n
  in
    assertIntListEqual "test iota" got expected
  end
  val cases = [
    (0, 3, [0, 1, 2]),
    (1, 3, [1, 2, 3]),
    (4, 1, [4])
  ]
in
  List.app evalCase cases
end

val _ = let
  val toInc = ref 0
  fun f () = ((toInc := !toInc + 1); !toInc)
  val kNumIters = 100
  val {resultsHash, times} = collectTiming kNumIters f
  val _ = assertIntEqual "test time count" kNumIters (Array.length times)
  (* copy+pasted golden value *)
  val kExpectHash = 0
  val _ = assertIntEqual "test hash" (Word32.toInt resultsHash) kExpectHash
in
  ()
end

fun toR32 (r: real): Real32.real =
    Real32.fromLarge IEEEReal.TO_NEAREST (Real.toLarge r)

val _ = let
  val times = Array.fromList [10.0, 1.0, 2.0, 3.0]
  val kHash = Word32.fromInt 1234
  val summary = calculateSummary ("test pfx", {resultsHash=kHash, times=times})
  val {min, max, avg, p50, stddev, ...} = summary
  val _ = assertRealEqual "test min" 1.0 (toR32 min)
  val _ = assertRealEqual "test max" 10.0 (toR32 max)
  val _ = assertRealEqual "test avg" 4.0 (toR32 avg)
  val _ = assertRealNear 0.001 "test stddev" 4.082 (toR32 stddev)
  (* p50: even length case *)
  val _ = assertRealEqual "test p50" 2.5 (toR32 p50)
  val _ = printSummary summary
in
  ()
end

val _ = let
  val times = Array.fromList [1.0, 2.0, 3.0]
  val kHash = Word32.fromInt 1234
  val {p50, ...}: benchmarkSummary =
      calculateSummary ("test pfx", {resultsHash=kHash, times=times})
  (* p50: odd length case *)
  val _ = assertRealEqual "test p50" 2.0 (toR32 p50)
in
  ()
end

val _ = summarizeRun()
