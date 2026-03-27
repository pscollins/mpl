(* Copyright (C) 2026 Patrick.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

structure Atoms = Atoms ()
structure Ssa2 = Ssa2 (open Atoms)
structure ParseSsa2 = ParseSsa2 (Ssa2)

local
   open Ssa2

   fun assertEqual (s1, s1', msg) =
      if s1 = s1' then () 
      else (print (msg ^ "\n"); 
            print "Expected:\n"; print s1; print "\n";
            print "Actual:\n"; print s1'; print "\n";
            OS.Process.exit OS.Process.failure)

   fun layoutToString p =
      let
         val lts = ref []
         val _ = Program.layouts (p, fn l => lts := l :: !lts)
      in
         Layout.toString (Layout.align (List.rev (!lts)))
      end

   val testDir = "testdata"
   val files = Dir.lsFiles testDir
   val ssa2Files = List.keepAll (files, fn f => String.hasSuffix (f, {suffix = ".ssa2"}))
   (* Sort files for deterministic output *)
   val ssa2Files = List.insertionSort (ssa2Files, String.<)

   val _ = print ("Running ParseSsa2 round-trip tests on " ^ Int.toString (List.length ssa2Files) ^ " files...\n")

   val _ = List.foreach (ssa2Files, fn f =>
      let
         val path = OS.Path.joinDirFile {dir = testDir, file = f}
         val _ = print ("Testing " ^ path ^ "...\n")
         val content = File.contents path
         
         (* First parse *)
         val p1 = ParseSsa2.parseString content
         val s1 = layoutToString p1
         
         (* Second parse (round-trip) *)
         val p2 = ParseSsa2.parseString s1
         val s2 = layoutToString p2
         
         val _ = assertEqual (s1, s2, "Round-trip layout mismatch for " ^ path)
         val _ = print ("Passed " ^ path ^ "\n")
      in
         ()
      end)

   val _ = print "All ParseSsa2 round-trip tests passed!\n"
in
end
