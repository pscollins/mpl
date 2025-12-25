structure Float32x8 = MLton.Float32x8

fun fromListWithStart start = let
    fun doLoad vec = Float32x8.fromVec (vec, start)
in
    doLoad o Vector.fromList
end

val fromList = fromListWithStart 0

val toList = (Vector.foldr (op ::) []) o Float32x8.toVec

val fromIntList = fromList o intsToReals

val _ = let
    fun evalCase orig = let
        val got = (toList o fromList) orig
    in
        assertReal32ListEqual "test list round-trip" orig got
    end
    val cases = List.map intsToReals [
            [1, 2, 3, 4, 5, 6, 7, 8],
            [2, 3, 4, 5, 6, 7, 8, 9]
    ]
in
    List.app evalCase cases
end

fun iota (start: int) (n: int): int list =
  List.tabulate (n, fn i => i + start) 

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
    val (wholeList: Real32.real list) = intsToReals (iota 1 20)
    fun evalCase (idx, expected) = let
        val (got: Real32.real list) = (toList o (fromListWithStart idx)) wholeList
    in
        assertReal32ListEqual "test load from index"
          (intsToReals expected) got
    end
    val cases = [
      (0, iota 1 8)
      (* TODO(pscollins): Cases for non-0-start loads *)
    ]
in
    List.app evalCase cases
end

val _ = let
    fun evalCase (lhs, rhs, want) = let
        val got = Float32x8.add
                      (fromIntList lhs)
                      (fromIntList rhs)
    in
        assertReal32ListEqual "test add"
                              (toList got)
                              (intsToReals want)
    end
    val cases = [
        ([1, 2, 3, 4, 5, 6, 7, 8],
         [0, 0, 0, 0, 0, 0, 0, 0],
         [1, 2, 3, 4, 5, 6, 7, 8]),

        ([1, 2, 3, 4, 5, 6, 7, 8],
         [2, 3, 4, 5, 6, 7, 8, 9],
         [3, 5, 7, 9, 11, 13, 15, 17])
    ]
in
    List.app evalCase cases
end

val _ = summarizeRun()
