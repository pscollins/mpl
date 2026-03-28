functor ParseSsa2 (S: SSA_TREE2): PARSE_SSA2 =
struct

structure Ssa2 = S
fun parseString (s: string): Ssa2.Program.t =
    let
       (* When parsing an SSA2 program from a string (e.g. for testing
        * or manually-written IR passes), we want to retain the names of
        * existing variables as they appear in the source.
        *
        * By default, the SSA parser will strip the uniquefying suffixes
        * from identifiers (e.g. 'x_1' becomes 'x') and then re-uniquefy
        * them during construction. This is because the SSA parser is
        * typically used to read IR that was produced by another stage of
        * the compiler, and we want to ensure that all IDs are fresh and
        * consistent with the current global ID counters.
        *
        * However, for manual IR rewriting or external tools, it is much
        * more convenient to preserve the exact names from the source.
        * 'setParseRetainNames true' enables this behavior, and it also
        * ensures that any new IDs generated *after* parsing will not
        * collide with the retained names by updating the global counters.
        *)
       val () = Ssa2.Tycon.setParseRetainNames true
       val () = Ssa2.Con.setParseRetainNames true
       val () = Ssa2.Var.setParseRetainNames true
       val () = Ssa2.Label.setParseRetainNames true
       val () = Ssa2.Func.setParseRetainNames true

       val res = Parse.parseString (Ssa2.Program.parse (), s)

       val () = Ssa2.Tycon.setParseRetainNames false
       val () = Ssa2.Con.setParseRetainNames false
       val () = Ssa2.Var.setParseRetainNames false
       val () = Ssa2.Label.setParseRetainNames false
       val () = Ssa2.Func.setParseRetainNames false
    in
       case res of
           Parse.Yes p => p
         | Parse.No (layout, loc) =>
           Error.bug (concat ["parse error at ", Int.toString (#line loc),
                              ":", Int.toString (#column loc), "\n",
                              Layout.toString layout])
    end
end
