
(* Utilities for running unit tests *)

(* Titles of passed tests *)
val passedTests: string list ref = ref []
(* Titles + reasons of failed *)
val failedTests: (string * string) list ref = ref  []

exception TestFail of string

(* Runs `thunk` and catches `TestFail` to indicate failure: passing tests are
collected in `passedTests` and failing tests + failing reasons in `failedTests` *)
fun runTest (title: string, thunk: unit -> unit): unit =
    (thunk (); passedTests := title :: !passedTests)
    handle TestFail reason =>
        (print ("Test failed: " ^ title ^ " - " ^ reason ^ "\n");
         failedTests := (title, reason) :: !failedTests)

exception SuiteFail
(* Summarizes the result of this run on stdout and raises SuiteFail for any failures *)
fun summarize(): unit =
    let
        val numPassed = List.length (!passedTests)
        val numFailed = List.length (!failedTests)
        val total = numPassed + numFailed
        val _ = print ("Summary of " ^ Int.toString total ^ " tests:\n")
        val _ = List.app (fn title => print ("PASS: " ^ title ^ "\n")) (List.rev (!passedTests))
        val _ = List.app (fn (title, reason) => print ("FAIL: " ^ title ^ " (" ^ reason ^ ")\n")) (List.rev (!failedTests))
        val _ = passedTests := []
        val _ = failedTests := []
    in
        if numFailed > 0 then raise SuiteFail else ()
    end
    
