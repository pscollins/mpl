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

val _ = summarizeRun()
