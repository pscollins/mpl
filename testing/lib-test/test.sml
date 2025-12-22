val _ = let
    val _ = assertIntEqual "foo" 1 1
    val _ = assertIntEqual "foo2" 2 2
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

val _ = summarizeRun()
