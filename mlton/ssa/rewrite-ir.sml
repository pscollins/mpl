structure Atoms = Atoms ()
structure Ssa2 = Ssa2 (open Atoms)
structure ParseSsa2 = ParseSsa2 (Ssa2)

local
   open Ssa2

   fun programToString (p: Program.t) : string =
      let
         val layouts = ref []
         val _ = Program.layouts (p, fn l => layouts := l :: !layouts)
      in
         Layout.toString (Layout.align (List.rev (!layouts)))
      end

   fun usage () =
      (print "Usage: rewrite-ir --infile=$INFILE --outfile=$OUTFILE\n";
       OS.Process.exit OS.Process.failure)

   val args = CommandLine.arguments ()
   
   fun parseArgs (args, infile, outfile) =
      case args of
         [] => (infile, outfile)
       | arg :: args =>
         if String.hasPrefix (arg, {prefix = "--infile="}) then
            parseArgs (args, SOME (String.substring (arg, 9, size arg - 9)), outfile)
         else if String.hasPrefix (arg, {prefix = "--outfile="}) then
            parseArgs (args, infile, SOME (String.substring (arg, 10, size arg - 10)))
         else
            parseArgs (args, infile, outfile)

   val (infile, outfile) = parseArgs (args, NONE, NONE)

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
   
   val _ = print "Parsing SSA2...\n"
   val program = ParseSsa2.parseString input
   
   val _ = print "Converting back to string...\n"
   val output = programToString program
   
   val _ = print ("Writing to " ^ outfile ^ "...\n")
   val _ = File.withOut (outfile, fn out => Out.output (out, output))
   
   val _ = print "Done.\n"
in
end
