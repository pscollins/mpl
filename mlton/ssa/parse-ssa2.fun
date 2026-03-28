functor ParseSsa2 (S: SSA_TREE2): PARSE_SSA2 =
struct

structure Ssa2 = S
fun parseString (s: string): Ssa2.Program.t =
    case Parse.parseString (Ssa2.Program.parse (), s) of
        Parse.Yes p => p
      | Parse.No (layout, loc) =>
        Error.bug (concat ["parse error at ", Int.toString (#line loc),
                           ":", Int.toString (#column loc), "\n",
                           Layout.toString layout])
end
