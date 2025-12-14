structure Float32x8 = MLton.Float32x8

val fromList = let
    fun doLoad vec = Float32x8.fromVec (vec, 0)
in
    doLoad o Real32Vector.fromList
end

val toList = (Real32Vector.foldr (op ::) []) o Float32x8.toVec

val intsToReals = List.map Real32.fromInt

val fromIntList = fromList o intsToReals

fun listToString (f: 'a -> string) (xs: 'a list) =
    String.concat [
        "[",
        (String.concatWith ", " (List.map f xs)),
        "]"
    ]

val real32ListToString = listToString Real32.toString

fun makeReal32listAsserter matchFn = {
    matchFn = matchFn,
    printFn = real32ListToString,
    quiet = false
}

fun listEq (pairEq: 'a * 'a -> bool) (xs: 'a list, ys: 'a list): bool =
    let
        val xsLen = List.length xs
        val ysLen = List.length ys
    in
        xsLen = ysLen andalso
        ListPair.all pairEq (xs, ys)
    end


fun real32ListEq (arg: Real32.real list * Real32.real list): bool =
    let
        fun pairEq (lhs: Real32.real, rhs: Real32.real) =
            Real32.compare (lhs, rhs) = EQUAL
    in
        listEq pairEq arg
    end

val real32ListEqAsserter = makeReal32listAsserter real32ListEq
val real32ListNeAsserter = makeReal32listAsserter (not o real32ListEq)


val assertReal32ListEqual = assertMatchWith real32ListEqAsserter
val assertReal32ListNotEqual = assertMatchWith real32ListNeAsserter

val _ = let
    val idx = ref 0
    fun evalCase (lhs, rhs) = let
    in
        assertReal32ListNotEqual "test negative assertions"
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
        assertReal32ListEqual "test positive assertions"
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
