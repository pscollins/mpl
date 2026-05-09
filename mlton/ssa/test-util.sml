
(* Utilities for running unit tests *)

(* Titles of passed tests *)
val passedTests: string list ref = ref []
(* Titles + reasons of failed *)
val failedTests: (string * string) list ref = ref  []

exception TestFail of string

(* Runs `thunk` and catches `TestFail` to indicate failure: passing tests are
collected in `passedTests` and failing tests + failing reasons in `failedTests` *)
fun runTest (title: string, thunk: unit -> unit): unit =
    ()
    (* TODO(gemini): Run `thunk` and catch TestFail: if it's raised, then
    increment failCount and print an error message containing the paylod string.
    Increment tesCount in any case
     *)

exception SuiteFail
(* Summarizes the result of this run on stdout and raises SuiteFail for any failures *)
fun summarize(): unit =
    ()
    (* TODO(gemini): Print a summary of the tests run: list each test case with
    a PASS/FAIL afterwards. At the end, if the count of failed tests is > 0,
    raise SuiteFail. Otherwise, do nothing. Reset the list of passed/failed
    tests afterwards *)
    
