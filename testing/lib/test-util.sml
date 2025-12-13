type 'a asserter = {
    matchFn: ('a * 'a) -> bool,
    printFn: 'a -> string,
    quiet: bool
}

exception FailedTest of string

fun printLn str = print (str ^ "\n")

fun assertMatchWith (asserter: 'a asserter)
                    (msgPfx: string)
                    (want: 'a)
                    (got: 'a) : unit =
    let
        val {matchFn, printFn, quiet} = asserter
        val success = matchFn (want, got)
        val statusMsg = if success then "Success!" else "FAIL!"
        val fullMsg = String.concat [
                msgPfx, ": ",
                statusMsg,
                " (want={", (printFn want), "}, vs ",
                "got={", (printFn got), "})"
            ]
        val _ = if quiet then () else printLn fullMsg
    in
        if success then ()
        else raise FailedTest fullMsg
    end

fun getIntEqualAsserter(): int asserter = {
    matchFn = fn (a, b) => a = b,
    printFn = Int.toString,
    quiet = false
}

val assertIntEqual: string -> int -> int -> unit
    = assertMatchWith (getIntEqualAsserter())
