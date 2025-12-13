val _ = let
    val _ = assertIntEqual "foo" 1 1
    val _ = assertIntEqual "foo2" 2 2
    val _ = let
        val _ = assertIntEqual "foo3" 1 0
        val _ = raise Fail "Did not raise expected exception!"
    in
        ()
    end
            handle FailedTest (msg) => print (String.concat ["Saw expected failure message: ", msg, "\n"])
in
    ()
end
