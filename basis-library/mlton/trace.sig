signature MLTON_TRACE = sig
    val sourceMark: string -> unit
    val sourceMarkValue: 'a * string -> unit
end
