structure Atoms = Atoms ()
structure Ssa = Ssa (open Atoms)
structure ParseSsa = ParseSsa (Ssa)
structure ExtractSsaSubgraph = ExtractSsaSubgraph (Ssa)

local
   open Ssa

   fun programToString (p: Program.t) : string =
      let
         val layouts = ref []
         val _ = Program.layouts (p, fn l => layouts := l :: !layouts)
         val l = Layout.align (List.rev (!layouts))
         val ss = ref []
      in
         Layout.print (l, fn s => ss := s :: !ss)
         ; String.concat (List.rev (!ss))
      end

   fun usage () =
      (print "Usage: rewrite-ir-ssa --infile=$INFILE --outfile=$OUTFILE [--extract_subgraph=$SSA_VALUE]\n";
       OS.Process.exit OS.Process.failure)

   val args = CommandLine.arguments ()
   
   fun parseArgs (args, infile, outfile, extractVar) =
      case args of
         [] => (infile, outfile, extractVar)
       | arg :: args =>
         if String.hasPrefix (arg, {prefix = "--infile="}) then
            parseArgs (args, SOME (String.substring (arg, 9, size arg - 9)), outfile, extractVar)
         else if String.hasPrefix (arg, {prefix = "--outfile="}) then
            parseArgs (args, infile, SOME (String.substring (arg, 10, size arg - 10)), extractVar)
         else if String.hasPrefix (arg, {prefix = "--extract_subgraph="}) then
            parseArgs (args, infile, outfile, SOME (String.substring (arg, 19, size arg - 19)))
         else
            parseArgs (args, infile, outfile, extractVar)

   val (infile, outfile, extractVar) = parseArgs (args, NONE, NONE, NONE)

   val infile =
      case infile of
         NONE => usage ()
       | SOME f => f
   
   val outfile =
      case outfile of
         NONE => usage ()
       | SOME f => f

   val _ = print ("Reading from " ^ infile ^ "...\n")
   val input = File.contents infile
   
   val _ = print "Parsing SSA...\n"
   val program = ParseSsa.parseString input
   
   fun findVar (p: Program.t, s: string): Var.t option =
      let
         val res = ref NONE
         val _ = Program.foreachVar (p, fn (v, _) =>
            if Var.toString v = s then res := SOME v else ())
      in
         !res
      end

   val program =
      case extractVar of
         NONE => program
       | SOME vStr =>
         (case findVar (program, vStr) of
             NONE => (print ("Could not find variable " ^ vStr ^ " in program.\n"); program)
           | SOME v =>
             let
                val _ = print ("Extracting subgraph for " ^ vStr ^ "...\n")
             in
                ExtractSsaSubgraph.isolateSubgraph (program, v)
             end)

   val _ = print "Converting back to string...\n"
   val output = programToString program
   
   val _ = print ("Writing to " ^ outfile ^ "...\n")
   val _ = File.withOut (outfile, fn out => Out.output (out, output))
   
   val _ = print "Done.\n"
in
end
