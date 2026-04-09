structure Atoms = Atoms ()
structure Ssa = Ssa (open Atoms)
structure PreFlatten = PreFlatten (Ssa)

local
   open Ssa

   val _ = print "Running PreFlatten tests...\n"

   fun assert (cond, msg) =
      if cond then () else (print ("Assertion failed: " ^ msg ^ "\n"); OS.Process.exit OS.Process.failure)

   fun assertEqualStrings (expected, actual, msg) =
      let
         fun join l =
            case l of
               [] => ""
             | [x] => x
             | x :: xs => x ^ ", " ^ (join xs)
         val e = join expected
         val a = join actual
      in
         if e = a then ()
         else (print (msg ^ "\n");
               print ("Expected: [" ^ e ^ "]\n");
               print ("Actual:   [" ^ a ^ "]\n");
               OS.Process.exit OS.Process.failure)
      end

   val log = ref []
   fun addLog s = log := s :: !log
   fun getLog () = List.rev (!log)
   fun clearLog () = log := []

   val walker = {
      beforeFunc = fn f => addLog ("beforeFunc " ^ (Func.toString (Function.name f))),
      afterFunc = fn f => addLog ("afterFunc " ^ (Func.toString (Function.name f))),
      beforeBlock = fn b => addLog ("beforeBlock " ^ (Label.toString (Block.label b))),
      afterBlock = fn b => addLog ("afterBlock " ^ (Label.toString (Block.label b))),
      statement = fn s => 
         case Statement.var s of
            SOME v => addLog ("statement " ^ (Var.toString v))
          | NONE => addLog "statement <none>"
   }

   (* Test 1: Simple program (existing) *)
   val _ = let
      val _ = print "Test 1: Simple program\n"
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
      
      val _ = PreFlatten.transform p1
      val _ = print "Test 1 passed\n"
   in () end

   (* Test 2: doWalk on simple program *)
   val _ = let
      val _ = print "Test 2: doWalk on simple program\n"
      val mainFunc = Func.fromString "main2"
      val mainLabel = Label.fromString "L1"
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
      val p2 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val _ = clearLog ()
      val _ = PreFlatten.doWalk (walker, p2)
      val expected = [
         "beforeFunc main2",
         "beforeBlock L1",
         "afterBlock L1",
         "afterFunc main2"
      ]
      val _ = assertEqualStrings (expected, getLog (), "doWalk sequence mismatch in Test 2")
      val _ = print "Test 2 passed\n"
   in () end

   (* Test 3: doWalk with statements *)
   val _ = let
      val _ = print "Test 3: doWalk with statements\n"
      val mainFunc = Func.fromString "main3"
      val mainLabel = Label.fromString "L2"
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val s1 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME v1}
      val s2 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME v2}
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.fromList [s1, s2],
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
      val p3 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val _ = clearLog ()
      val _ = PreFlatten.doWalk (walker, p3)
      val expected = [
         "beforeFunc main3",
         "beforeBlock L2",
         "statement v1",
         "statement v2",
         "afterBlock L2",
         "afterFunc main3"
      ]
      val _ = assertEqualStrings (expected, getLog (), "doWalk sequence mismatch in Test 3")
      val _ = print "Test 3 passed\n"
   in () end

   (* Test 4: doWalk with globals *)
   val _ = let
      val _ = print "Test 4: doWalk with globals\n"
      val g1 = Var.fromString "g1"
      val g2 = Var.fromString "g2"
      val gs1 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME g1}
      val gs2 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME g2}
      
      val mainFunc = Func.fromString "main4"
      val mainLabel = Label.fromString "L3"
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
      val p4 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.fromList [gs1, gs2],
         main = mainFunc
      }
      
      val _ = clearLog ()
      val _ = PreFlatten.doWalk (walker, p4)
      val expected = [
         "statement g1",
         "statement g2",
         "beforeFunc main4",
         "beforeBlock L3",
         "afterBlock L3",
         "afterFunc main4"
      ]
      val _ = assertEqualStrings (expected, getLog (), "doWalk sequence mismatch in Test 4")
      val _ = print "Test 4 passed\n"
   in () end

   (* Test 5: Complex walk *)
   val _ = let
      val _ = print "Test 5: Complex walk\n"
      val f1Name = Func.fromString "f1"
      val f1L1 = Label.fromString "f1L1"
      val f1L2 = Label.fromString "f1L2"
      val v1 = Var.fromString "v1"
      val s1 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME v1}
      val b1 = Block.T {
         args = Vector.new0 (),
         label = f1L1,
         statements = Vector.fromList [s1],
         transfer = Transfer.Goto {args = Vector.new0 (), dst = f1L2}
      }
      val b2 = Block.T {
         args = Vector.new0 (),
         label = f1L2,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f1 = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [b1, b2],
         inline = InlineAttr.Auto,
         name = f1Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f1L1
      }
      
      val f2Name = Func.fromString "f2"
      val f2L1 = Label.fromString "f2L1"
      val v2 = Var.fromString "v2"
      val s2 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME v2}
      val b3 = Block.T {
         args = Vector.new0 (),
         label = f2L1,
         statements = Vector.fromList [s2],
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f2 = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [b3],
         inline = InlineAttr.Auto,
         name = f2Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f2L1
      }

      val p5 = Program.T {
         datatypes = Vector.new0 (),
         functions = [f1, f2],
         globals = Vector.new0 (),
         main = f1Name
      }
      
      val _ = clearLog ()
      val _ = PreFlatten.doWalk (walker, p5)
      val expected = [
         "beforeFunc f1",
         "beforeBlock f1L1",
         "statement v1",
         "afterBlock f1L1",
         "beforeBlock f1L2",
         "afterBlock f1L2",
         "afterFunc f1",
         "beforeFunc f2",
         "beforeBlock f2L1",
         "statement v2",
         "afterBlock f2L1",
         "afterFunc f2"
      ]
      val _ = assertEqualStrings (expected, getLog (), "doWalk sequence mismatch in Test 5")
      val _ = print "Test 5 passed\n"
   in () end
in
end
