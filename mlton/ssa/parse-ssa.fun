functor ParseSsa (S: SSA_TREE): PARSE_SSA =
struct

structure Ssa = S
fun parseString (s: string): Ssa.Program.t =
    let
       val () = Ssa.Tycon.setParseRetainNames true
       val () = Ssa.Con.setParseRetainNames true
       val () = Ssa.Var.setParseRetainNames true
       val () = Ssa.Label.setParseRetainNames true
       val () = Ssa.Func.setParseRetainNames true

       val res = Parse.parseString (Ssa.Program.parse (), s)

       val () = Ssa.Tycon.setParseRetainNames false
       val () = Ssa.Con.setParseRetainNames false
       val () = Ssa.Var.setParseRetainNames false
       val () = Ssa.Label.setParseRetainNames false
       val () = Ssa.Func.setParseRetainNames false
    in
       case res of
           Parse.Yes p => p
         | Parse.No (layout, loc) =>
           Error.bug (concat ["parse error at ", Int.toString (#line loc),
                              ":", Int.toString (#column loc), "\n",
                              Layout.toString layout])
    end
end
