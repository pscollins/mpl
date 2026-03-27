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

   fun assert (cond, msg) =
      if cond then () else (print ("Assertion failed: " ^ msg ^ "\n"); OS.Process.exit OS.Process.failure)

   fun layoutToString p =
      let
         val lts = ref []
         val _ = Program.layouts (p, fn l => lts := l :: !lts)
      in
         Layout.toString (Layout.align (List.rev (!lts)))
      end

   fun assertEqual (s1, s1', msg) =
      if s1 = s1' then () 
      else (print (msg ^ "\n"); 
            print "Expected:\n"; print s1; print "\n";
            print "Actual:\n"; print s1'; print "\n";
            OS.Process.exit OS.Process.failure)

   val _ = print "Running ParseSsa2 tests...\n"

   (* Test 1: Simple program round-trip *)
   val _ = let
      val _ = print "Test 1: Simple program round-trip\n"
      val mainFunc = Func.fromString "main"
      val mainLabel = Label.fromString "L0"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
      }
      val p1 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val s1 = layoutToString p1
      val p1' = ParseSsa2.parseString s1
      val s1' = layoutToString p1'
      
      val _ = assertEqual (s1, s1', "Round-trip layout mismatch in Test 1")
      val _ = print "Test 1 passed\n"
   in () end

   (* Test 2: Program with globals and statements *)
   val _ = let
      val _ = print "Test 2: Program with globals and statements\n"
      val mainFunc = Func.fromString "main2"
      val mainLabel = Label.fromString "L1"
      
      val var1 = Var.fromString "v1"
      val ty1 = Type.intInf
      
      val stmt1 = Statement.Bind {
         exp = Exp.Const (Const.IntInf 42),
         ty = ty1,
         var = SOME var1
      }
      
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.fromList [stmt1],
         transfer = Transfer.Return (Vector.new0 ())
      }
      
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
      }
      
      val p2 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val s2 = layoutToString p2
      val p2' = ParseSsa2.parseString s2
      val s2' = layoutToString p2'
      
      val _ = assertEqual (s2, s2', "Round-trip layout mismatch in Test 2")
      val _ = print "Test 2 passed\n"
   in () end

   val _ = print "All ParseSsa2 tests passed!\n"
in
end
