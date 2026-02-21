signature MLTON_TRACE = sig

   (* Emits a `// Diagnostic(...)` comment in the generated C, where the
   contents of the comment is the string argument. *)
    val sourceMark: string -> unit

    (* Like above, but consumes a value. The generated comment contains the name
    of the value in `Machine` IR. This is helpful for the sake of limiting code
    movement around the mark. *)
    val sourceMarkValue: 'a * string -> unit

    (* `noHeap  *)
    val noHeap: 'a -> 'a
end
