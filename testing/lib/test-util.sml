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

val kDefaultQuiet = false

(* Assertions+utilities for int *)
fun getIntEqualAsserter(): int asserter = {
    matchFn = fn (a, b) => a = b,
    printFn = Int.toString,
    quiet = kDefaultQuiet
}

val assertIntEqual: string -> int -> int -> unit
    = assertMatchWith (getIntEqualAsserter())

(* Assertions+utilities for real32 *)
fun getRealEqualAsserter(): Real32.real asserter = {
    matchFn = fn (a, b) => (Real32.compare (a, b) = EQUAL),
    printFn = Real32.toString,
    quiet = kDefaultQuiet
}

val assertRealEqual: string -> Real32.real -> Real32.real -> unit
    = assertMatchWith (getRealEqualAsserter())

fun getRealNearAsserter (tol: real): Real32.real asserter = let
  val tol' = Real32.fromLarge IEEEReal.TO_NEAREST tol
  fun checkNear (a, b) = let
    val diff = Real32.abs (Real32.- (a, b))
  in
    Real32.compare (diff, tol') = LESS
  end
in
  {
    matchFn = checkNear,
    printFn = Real32.toString,
    quiet = kDefaultQuiet
  }
end

fun assertRealNear (tol: real): string -> Real32.real -> Real32.real -> unit
    = assertMatchWith (getRealNearAsserter tol)

(* Assertions+utilities for real list *)
fun listToString (f: 'a -> string) (xs: 'a list) =
    String.concat [
        "[",
        (String.concatWith ", " (List.map f xs)),
        "]"
    ]

val intsToReals = List.map Real32.fromInt

val real32ListToString = listToString Real32.toString

fun makeReal32ListAsserter matchFn = {
    matchFn = matchFn,
    printFn = real32ListToString,
    quiet = kDefaultQuiet
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

val real32ListEqAsserter = makeReal32ListAsserter real32ListEq
val real32ListNeAsserter = makeReal32ListAsserter (not o real32ListEq)

val assertReal32ListEqual = assertMatchWith real32ListEqAsserter
val assertReal32ListNotEqual = assertMatchWith real32ListNeAsserter

(* Assertions+utilities for real list list *)
val real32ListListToString = listToString (listToString Real32.toString)

fun makeReal32ListListAsserter matchFn = {
    matchFn = matchFn,
    printFn = real32ListListToString,
    quiet = kDefaultQuiet
}

fun real32ListListEq (arg: Real32.real list list * Real32.real list list): bool =
        listEq real32ListEq arg

val real32ListListEqAsserter = makeReal32ListListAsserter real32ListListEq
val real32ListListNeAsserter = makeReal32ListListAsserter (not o real32ListListEq)

val assertReal32ListListEqual = assertMatchWith real32ListListEqAsserter
val assertReal32ListListNotEqual = assertMatchWith real32ListListNeAsserter

(* Assertions+utilities for int list *)
val intListToString = (listToString Int.toString)

fun makeIntListAsserter matchFn = {
    matchFn = matchFn,
    printFn = intListToString,
    quiet = kDefaultQuiet
}

fun equalityTypeListEq (arg: ''a list * ''a list): bool =
        listEq (fn (x, y) => x = y) arg

val intListEqAsserter = makeIntListAsserter equalityTypeListEq
val intListNeAsserter = makeIntListAsserter (not o equalityTypeListEq)

val assertIntListEqual = assertMatchWith intListEqAsserter
val assertIntListNotEqual = assertMatchWith intListNeAsserter

(* Assertions for exception handling *)
fun assertRaises (msgPrefix: string) (f: unit -> 'b) (wantName: string) = let
  val failMsg = String.concat [msgPrefix, ": wanted ", wantName, " but nothing was raised"]
in
  (f(); printLn failMsg; raise FailedTest failMsg)
end
  handle e => let
    val gotName = exnName e
    val msg = String.concat [msgPrefix, ": want raised ", wantName, " vs got ", gotName]
    val () = if not kDefaultQuiet then printLn msg  else ()
  in
    if gotName <> wantName then raise FailedTest msg else ()
  end

(* General utilities  *)
fun iota (start: int) (n: int): int list =
  List.tabulate (n, fn i => i + start)
