structure Float32x8 = MLton.Float32x8

val fromList = let
    fun doLoad vec = Float32x8.fromVec (vec, 0)
in
    doLoad o Vector.fromList
end

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
