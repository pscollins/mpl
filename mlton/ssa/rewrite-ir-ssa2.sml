structure Atoms = Atoms ()
structure Ssa2 = Ssa2 (open Atoms)
structure ParseSsa2 = ParseSsa2 (Ssa2)
structure RewriteSsa2 = RewriteSsa2 (Ssa2)

local
   open Ssa2

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
      (print "Usage: rewrite-ir-ssa2 --infile=$INFILE --outfile=$OUTFILE [--isolate_subgraph=$SSA_VALUE]\n";
       OS.Process.exit OS.Process.failure)

   val args = CommandLine.arguments ()
   
   fun parseArgs (args, infile, outfile, isolateVar) =
      case args of
         [] => (infile, outfile, isolateVar)
       | arg :: args =>
         if String.hasPrefix (arg, {prefix = "--infile="}) then
            parseArgs (args, SOME (String.substring (arg, 9, size arg - 9)), outfile, isolateVar)
         else if String.hasPrefix (arg, {prefix = "--outfile="}) then
            parseArgs (args, infile, SOME (String.substring (arg, 10, size arg - 10)), isolateVar)
         else if String.hasPrefix (arg, {prefix = "--isolate_subgraph="}) then
            parseArgs (args, infile, outfile, SOME (String.substring (arg, 19, size arg - 19)))
         else
            parseArgs (args, infile, outfile, isolateVar)

   val (infile, outfile, isolateVar) = parseArgs (args, NONE, NONE, NONE)

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
   
   fun findVar (p: Program.t, s: string): Var.t option =
      let
         val res = ref NONE
         val _ = Program.foreachVar (p, fn (v, _) =>
            if Var.toString v = s then res := SOME v else ())
      in
         !res
      end

   val program =
      case isolateVar of
         NONE => program
       | SOME vStr =>
         (case findVar (program, vStr) of
             NONE => (print ("Could not find variable " ^ vStr ^ " in program.\n"); program)
           | SOME v =>
             let
                val _ = print ("Isolating subgraph for " ^ vStr ^ "...\n")
             in
                RewriteSsa2.isolateSubgraph (program, v)
             end)

   val _ = print "Converting back to string...\n"
   val output = programToString program
   
   val _ = print ("Writing to " ^ outfile ^ "...\n")
   val _ = File.withOut (outfile, fn out => Out.output (out, output))
   
   val _ = print "Done.\n"
in
end
