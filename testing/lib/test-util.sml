type 'a asserter = {
    matchFn: ('a * 'a) -> bool,
    printFn: 'a -> string,
    quiet: bool
}

exception FailedTest of string

(* prints a string, adding a newline *)
fun printLn str = print (str ^ "\n")
(* prints an array of strings *)
val printArrLn = (printLn o String.concat)

local
    val testCount: int ref = ref 0
in
fun incTestCount() = testCount := (!testCount + 1)
fun getTestCount() = !testCount
end

(* prints a summary of all tests run in this invocation *)
fun summarizeRun() = let
    val numRuns = (Int.toString o getTestCount)()
    val marker = "===="
    val msgParts = [
        marker,
        " ",
        "Successfully completed ",
        numRuns,
        " tests.",
        " ",
        marker
        ]
in
    printArrLn msgParts
end

(* compares `want` to `got` according to the contents of `asserter`, raising
`FailedTest` on failure. *)
fun assertMatchWith (asserter: 'a asserter)
                    (msgPfx: string)
                    (want: 'a) (got: 'a) : unit =
    let
        val _ = incTestCount ()
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

(* Assertions+utilities for int *)
fun getIntEqualAsserter(): int asserter = {
    matchFn = fn (a, b) => a = b,
    printFn = Int.toString,
    quiet = false
}

val assertIntEqual: string -> int -> int -> unit
    = assertMatchWith (getIntEqualAsserter())

(* Assertions+utilities for real *)
fun listToString (f: 'a -> string) (xs: 'a list) =
    String.concat [
        "[",
        (String.concatWith ", " (List.map f xs)),
        "]"
    ]

val intsToReals = List.map Real32.fromInt

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
