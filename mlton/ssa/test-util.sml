
(* Utilities for running unit tests *)

(* Titles of passed tests *)
val passedTests: string list ref = ref []
(* Titles of failed *)
val failedTests: string list ref = ref  []

exception TestFail of string

fun runTest (title: string, thunk: unit -> unit): unit =
    (* TODO(gemini): Run `thunk` and catch TestFail: if it's raised, then
    increment failCount and print an error message containing the paylod string.
    Increment tesCount in any case
     *)

exception SuiteFail
fun summarize(): unit =
    (* TODO(gemini): Print a summary of the tests run: list each test case with
    a PASS/FAIL afterwards. At the end, if the count of failed tests is > 0,
    raise SuiteFail. Otherwise, do nothing *)
    
