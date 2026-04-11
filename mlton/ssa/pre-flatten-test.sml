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
      val f2Name = Func.fromString "f2"
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
         transfer = Transfer.Call {
            args = Vector.new0 (),
            func = f2Name,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
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

   (* Test 6: flattenTupleVar *)
   val _ = let
      val _ = print "Test 6: flattenTupleVar\n"
      
      val t1 = Type.bool
      val t2 = Type.unit
      val tTuple = Type.tuple (Vector.fromList [t1, t2])
      
      val v = Var.fromString "v"
      
      val _ = print "Test 6a: flattening a 2-tuple\n"
      val res = PreFlatten.flattenTupleVar (v, tTuple)
      val _ = 
         case res of
            NONE => (print "flattenTupleVar returned NONE for tuple type\n"; OS.Process.exit OS.Process.failure)
          | SOME vts =>
               let
                  val _ = assert (Vector.length vts = 2, "flattenTupleVar result length mismatch")
                  val (v1, t1') = Vector.sub (vts, 0)
                  val (v2, t2') = Vector.sub (vts, 1)
                  val _ = assert (Type.equals (t1, t1'), "flattenTupleVar type 1 mismatch")
                  val _ = assert (Type.equals (t2, t2'), "flattenTupleVar type 2 mismatch")
                  val _ = assert (not (Var.equals (v1, v)), "flattenTupleVar var 1 should be fresh")
                  val _ = assert (not (Var.equals (v2, v)), "flattenTupleVar var 2 should be fresh")
                  val _ = assert (not (Var.equals (v1, v2)), "flattenTupleVar vars should be distinct")
               in () end
               
      val _ = print "Test 6b: flattening a non-tuple\n"
      val resNonTuple = PreFlatten.flattenTupleVar (v, t1)
      val _ = 
         case resNonTuple of
            NONE => ()
          | SOME _ => (print "flattenTupleVar should return NONE for non-tuple type\n"; OS.Process.exit OS.Process.failure)
      
      val _ = print "Test 6 passed\n"
   in () end

   (* Test 7: buildBindBlock *)
   val _ = let
      val _ = print "Test 7: buildBindBlock\n"
      val toVar = Var.fromString "t"
      val f1 = Var.fromString "f1"
      val f2 = Var.fromString "f2"
      val binds = Vector.fromList [PreFlatten.BindTuple {to = (toVar, Type.unit), froms = Vector.fromList [f1, f2]}]
      val targetLabel = Label.fromString "target"
      
      val block = PreFlatten.buildBindBlock (binds, targetLabel)
      val Block.T {args, label = _, statements, transfer} = block
      
      val _ = assert (Vector.length args = 0, "buildBindBlock block should have no args")
      val _ = assert (Vector.length statements = 1, "buildBindBlock should have 1 statement")
      
      val s0 = Vector.sub (statements, 0)
      val Statement.T {exp, var, ...} = s0
      val _ = 
         case var of
            SOME v => assert (Var.equals (v, toVar), "statement var mismatch")
          | NONE => (print "statement should have a var\n"; OS.Process.exit OS.Process.failure)
          
      val _ = 
         case exp of
            Exp.Tuple vs =>
               let
                  val _ = assert (Vector.length vs = 2, "tuple exp should have 2 args")
                  val _ = assert (Var.equals (Vector.sub (vs, 0), f1), "tuple arg 1 mismatch")
                  val _ = assert (Var.equals (Vector.sub (vs, 1), f2), "tuple arg 2 mismatch")
               in () end
          | _ => (print "exp should be a tuple\n"; OS.Process.exit OS.Process.failure)
          
      val _ = 
         case transfer of
            Transfer.Goto {args, dst} =>
               let
                  val _ = assert (Vector.length args = 0, "goto should have no args")
                  val _ = assert (Label.equals (dst, targetLabel), "goto dst mismatch")
               in () end
          | _ => (print "transfer should be a goto\n"; OS.Process.exit OS.Process.failure)

      val _ = print "Test 7 passed\n"
   in () end

   (* Test 8: buildBindBlock with multiple binds *)
   val _ = let
      val _ = print "Test 8: buildBindBlock with multiple binds\n"
      val t1 = Var.fromString "t1"
      val f1 = Var.fromString "f1"
      val t2 = Var.fromString "t2"
      val f2 = Var.fromString "f2"
      val f3 = Var.fromString "f3"
      val binds = Vector.fromList [
         PreFlatten.BindTuple {to = (t1, Type.unit), froms = Vector.fromList [f1]},
         PreFlatten.BindTuple {to = (t2, Type.unit), froms = Vector.fromList [f2, f3]}
      ]
      val targetLabel = Label.fromString "target2"
      
      val block = PreFlatten.buildBindBlock (binds, targetLabel)
      val Block.T {statements, ...} = block
      
      val _ = assert (Vector.length statements = 2, "buildBindBlock should have 2 statements")
      val _ = print "Test 8 passed\n"
   in () end

   (* Test 9: buildBindBlock with empty binds *)
   val _ = let
      val _ = print "Test 9: buildBindBlock with empty binds\n"
      val targetLabel = Label.fromString "target3"
      val block = PreFlatten.buildBindBlock (Vector.new0 (), targetLabel)
      val Block.T {statements, ...} = block
      val _ = assert (Vector.length statements = 0, "buildBindBlock should have 0 statements")
      val _ = print "Test 9 passed\n"
   in () end

   (* Test 10: buildFlattenedFunction with Preserve and FlattenTuple *)
   val _ = let
      val _ = print "Test 10: buildFlattenedFunction with Preserve and FlattenTuple\n"
      val fName = Func.fromString "f10"
      val l1 = Label.fromString "L10"
      val v1 = Var.fromString "v1"
      val t1 = Type.bool
      val v2 = Var.fromString "v2"
      val t2 = Type.unit
      val tTuple = Type.tuple (Vector.fromList [t1, t2])
      val b1 = Block.T {
         args = Vector.fromList [(v1, t1), (v2, tTuple)],
         label = l1,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.fromList [v1])
      }
      val f = Function.new {
         args = Vector.fromList [(v1, t1), (v2, tTuple)],
         blocks = Vector.fromList [b1],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.fromList [t1]),
         start = l1
      }
      
      val res = PreFlatten.buildFlattenedFunction (f, Vector.fromList [PreFlatten.Preserve, PreFlatten.FlattenTuple])
      val {args, blocks, start, ...} = Function.dest res
      val _ = assert (Vector.length args = 3, "Flattened function should have 3 args")
      val (_, rt0) = Vector.sub (args, 0)
      val (_, rt1) = Vector.sub (args, 1)
      val (_, rt2) = Vector.sub (args, 2)
      val _ = assert (Type.equals (rt0, t1), "Arg 0 type mismatch")
      val _ = assert (Type.equals (rt1, t1), "Arg 1 type mismatch")
      val _ = assert (Type.equals (rt2, t2), "Arg 2 type mismatch")
      
      val startBlock = Vector.peek (blocks, fn b => Label.equals (Block.label b, start))
      val _ = case startBlock of
         SOME (Block.T {statements, ...}) =>
            let
               val found = Vector.exists (statements, fn Statement.T {var, ...} =>
                  case var of
                     SOME v => Var.equals (v, v2)
                   | NONE => false)
               val _ = assert (found, "Original var v2 not found in statements")
            in () end
       | NONE => (print "Start block not found\n"; OS.Process.exit OS.Process.failure)
      val _ = print "Test 10 passed\n"
   in () end

   (* Test 11: varChoiceManager lifecycle and default choice *)
   val _ = let
      val _ = print "Test 11: varChoiceManager lifecycle and default choice\n"
      val vcm = PreFlatten.newVarChoiceManager ()
      val v = Var.fromString "v11"
      val choice = PreFlatten.getVarChoice (vcm, v)
      val _ = 
         case choice of
            PreFlatten.PreserveVar => ()
          | _ => (print "Default choice should be PreserveVar\n"; OS.Process.exit OS.Process.failure)
      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 11 passed\n"
   in () end

   (* Test 12: chooseVarsInStatement *)
   val _ = let
      val _ = print "Test 12: chooseVarsInStatement\n"
      val vcm = PreFlatten.newVarChoiceManager ()
      
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val vTuple = Var.fromString "vt"
      
      val sTuple = Statement.T {
         exp = Exp.Tuple (Vector.fromList [v1, v2]),
         ty = Type.unit, (* Type doesn't strictly matter for chooseVarsInStatement logic as described *)
         var = SOME vTuple
      }
      
      val sNonTuple = Statement.T {
         exp = Exp.unit,
         ty = Type.unit,
         var = SOME v1
      }
      
      val _ = PreFlatten.chooseVarsInStatement (vcm, sTuple)
      val _ = PreFlatten.chooseVarsInStatement (vcm, sNonTuple)
      
      val choiceTuple = PreFlatten.getVarChoice (vcm, vTuple)
      val _ = 
         case choiceTuple of
            PreFlatten.FlattenTupleVar vs =>
               let
                  val _ = assert (Vector.length vs = 2, "FlattenTupleVar should have 2 vars")
                  val _ = assert (Var.equals (Vector.sub (vs, 0), v1), "FlattenTupleVar var 0 mismatch")
                  val _ = assert (Var.equals (Vector.sub (vs, 1), v2), "FlattenTupleVar var 1 mismatch")
               in () end
          | _ => (print "vt should be FlattenTupleVar\n"; OS.Process.exit OS.Process.failure)
          
      val choiceNonTuple = PreFlatten.getVarChoice (vcm, v1)
      val _ = 
         case choiceNonTuple of
            PreFlatten.PreserveVar => ()
          | _ => (print "v1 should be PreserveVar\n"; OS.Process.exit OS.Process.failure)
          
      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 12 passed\n"
   in () end

   (* Test 13: newVarChoicesForProgram *)
   val _ = let
      val _ = print "Test 13: newVarChoicesForProgram\n"
      
      val g1 = Var.fromString "g1"
      val g2 = Var.fromString "g2"
      val gt = Var.fromString "gt"
      (* gt = (g1, g2) *)
      val gs1 = Statement.T {exp = Exp.Tuple (Vector.fromList [g1, g2]), ty = Type.unit, var = SOME gt}
      val gs2 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME g1}
      
      val mainFunc = Func.fromString "main13"
      val mainLabel = Label.fromString "L13"
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val vt = Var.fromString "vt"
      (* vt = (v1, v2) *)
      val s1 = Statement.T {exp = Exp.Tuple (Vector.fromList [v1, v2]), ty = Type.unit, var = SOME vt}
      val s2 = Statement.T {exp = Exp.unit, ty = Type.unit, var = SOME v1}
      
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.fromList [gs1, gs2],
         main = mainFunc
      }
      
      val vcm = PreFlatten.newVarChoicesForProgram p
      
      val choiceGt = PreFlatten.getVarChoice (vcm, gt)
      val _ = 
         case choiceGt of
            PreFlatten.FlattenTupleVar vs =>
               let
                  val _ = assert (Vector.length vs = 2, "gt should have 2 components")
                  val _ = assert (Var.equals (Vector.sub (vs, 0), g1), "gt component 0 mismatch")
                  val _ = assert (Var.equals (Vector.sub (vs, 1), g2), "gt component 1 mismatch")
               in () end
          | _ => (print "gt should be FlattenTupleVar\n"; OS.Process.exit OS.Process.failure)

      val choiceVt = PreFlatten.getVarChoice (vcm, vt)
      val _ = 
         case choiceVt of
            PreFlatten.FlattenTupleVar vs =>
               let
                  val _ = assert (Vector.length vs = 2, "vt should have 2 components")
                  val _ = assert (Var.equals (Vector.sub (vs, 0), v1), "vt component 0 mismatch")
                  val _ = assert (Var.equals (Vector.sub (vs, 1), v2), "vt component 1 mismatch")
               in () end
          | _ => (print "vt should be FlattenTupleVar\n"; OS.Process.exit OS.Process.failure)

      val choiceG1 = PreFlatten.getVarChoice (vcm, g1)
      val _ = 
         case choiceG1 of
            PreFlatten.PreserveVar => ()
          | _ => (print "g1 should be PreserveVar\n"; OS.Process.exit OS.Process.failure)

      val choiceV1 = PreFlatten.getVarChoice (vcm, v1)
      val _ = 
         case choiceV1 of
            PreFlatten.PreserveVar => ()
          | _ => (print "v1 should be PreserveVar\n"; OS.Process.exit OS.Process.failure)

      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 13 passed\n"
   in () end

   (* Test 14: checkFlatteningChoice *)
   val _ = let
      val _ = print "Test 14: checkFlatteningChoice\n"
      val fName = Func.fromString "f14"
      val l1 = Label.fromString "L14"
      val v1 = Var.fromString "v1"
      val t1 = Type.bool
      val v2 = Var.fromString "v2"
      val t2 = Type.unit
      val tTuple = Type.tuple (Vector.fromList [t1, t2])
      
      val f = Function.new {
         args = Vector.fromList [(v1, t1), (v2, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.fromList [(v1, t1), (v2, tTuple)],
            label = l1,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = l1
      }

      val _ = print "Test 14a: NoOp choice\n"
      val resNoOp = PreFlatten.checkFlatteningChoice (f, Vector.fromList [PreFlatten.Preserve, PreFlatten.Preserve])
      val _ = case resNoOp of
         PreFlatten.NoOp => ()
       | _ => (print "Expected NoOp\n"; OS.Process.exit OS.Process.failure)

      val _ = print "Test 14b: Valid choice\n"
      val resValid = PreFlatten.checkFlatteningChoice (f, Vector.fromList [PreFlatten.Preserve, PreFlatten.FlattenTuple])
      val _ = case resValid of
         PreFlatten.Valid => ()
       | _ => (print "Expected Valid\n"; OS.Process.exit OS.Process.failure)

      val _ = print "Test 14c: Invalid choice (arity mismatch)\n"
      val resInvalidArity = PreFlatten.checkFlatteningChoice (f, Vector.fromList [PreFlatten.Preserve])
      val _ = case resInvalidArity of
         PreFlatten.Invalid => ()
       | _ => (print "Expected Invalid due to arity\n"; OS.Process.exit OS.Process.failure)

      val _ = print "Test 14d: Invalid choice (flattening a non-tuple)\n"
      val resInvalidNonTuple = PreFlatten.checkFlatteningChoice (f, Vector.fromList [PreFlatten.FlattenTuple, PreFlatten.Preserve])
      val _ = case resInvalidNonTuple of
         PreFlatten.Invalid => ()
       | _ => (print "Expected Invalid due to non-tuple flattening\n"; OS.Process.exit OS.Process.failure)

      val _ = print "Test 14 passed\n"
   in () end

   (* Test 15: functionManager *)
   val _ = let
      val _ = print "Test 15: functionManager\n"
      val fName = Func.fromString "f15"
      val l1 = Label.fromString "L15"
      val v1 = Var.fromString "v1"
      val t1 = Type.bool
      val v2 = Var.fromString "v2"
      val t2 = Type.unit
      val tTuple = Type.tuple (Vector.fromList [t1, t2])
      
      val f = Function.new {
         args = Vector.fromList [(v1, t1), (v2, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.fromList [(v1, t1), (v2, tTuple)],
            label = l1,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = l1
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [f],
         globals = Vector.new0 (),
         main = fName
      }

      val fm = PreFlatten.newFunctionManager p
      
      val _ = print "Test 15a: getOrCreateFunc NoOp\n"
      val fNoOp = PreFlatten.getOrCreateFunc (fm, fName, Vector.fromList [PreFlatten.Preserve, PreFlatten.Preserve])
      val _ = assert (Func.equals (fNoOp, fName), "NoOp should return original Func.t")
      
      val _ = print "Test 15b: extractNewFunctions after NoOp\n"
      val newFuncs0 = PreFlatten.extractNewFunctions fm
      val _ = assert (List.length newFuncs0 = 0, "No new functions should be extracted after NoOp")
      
      val _ = print "Test 15c: getOrCreateFunc Valid\n"
      val fFlattened = PreFlatten.getOrCreateFunc (fm, fName, Vector.fromList [PreFlatten.Preserve, PreFlatten.FlattenTuple])
      val _ = assert (not (Func.equals (fFlattened, fName)), "Valid flattening should return new Func.t")
      
      val _ = print "Test 15d: extractNewFunctions after Valid\n"
      val newFuncs1 = PreFlatten.extractNewFunctions fm
      val _ = assert (List.length newFuncs1 = 1, "One new function should be extracted")
      val f1 = case newFuncs1 of (x::_) => x | _ => (print "Expected non-empty list\n"; OS.Process.exit OS.Process.failure)
      val _ = assert (Func.equals (Function.name f1, fFlattened), "Extracted function name mismatch")
      
      val _ = print "Test 15e: extractNewFunctions should clear pending\n"
      val newFuncs2 = PreFlatten.extractNewFunctions fm
      val _ = assert (List.length newFuncs2 = 0, "extractNewFunctions should clear pending list")
      
      val _ = PreFlatten.destroyFunctionManager fm
      val _ = print "Test 15 passed\n"
   in () end
in
end
