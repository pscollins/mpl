signature MLTON_TRACE = sig
    val sourceMark: string -> unit
    val sourceMarkValue: 'a * string -> unit
    val sourceMarkValueReturn: 'a * string -> 'a
end
