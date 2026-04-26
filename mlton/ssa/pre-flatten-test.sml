structure Atoms = Atoms ()
structure Ssa = Ssa (open Atoms)
structure PreFlatten = PreFlatten (Ssa)

val _ = Control.diagnosticWriter := SOME (fn l => Layout.outputl (l, Out.standard))

(* Debug helper for printing *)
fun programToString program =
    let
       val segments = ref []
       (* Accumulate each layout part into the segments list *)
       val _ = Ssa.Program.layouts (program, fn l =>
                                                Layout.print (l, fn s => segments := s :: !segments))
    in
       String.concat (List.rev (!segments))
    end

fun printProgram (label, program) = let 
   val msgParts = [
      "Program ",
      label,
      "contents: \n",
      programToString program,
      "\n"
      ]
in
   print (String.concat msgParts)
end

fun printFail msg =
    (print (msg ^ "\n");
     OS.Process.exit OS.Process.failure)

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

   fun choiceResToString res =
      case res of
         PreFlatten.NoOp => "NoOp"
       | PreFlatten.Valid => "Valid"
       | PreFlatten.Invalid => "Invalid"

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

   (* TODO(gemini): renumber tests *)
   (* Test 14: Simple program (existing) *)
   val _ = let
      val _ = print "Test 14: mapBlocks\n"
      val mainFunc = Func.fromString "main"
      val mainLabel = Label.fromString "L0"
      fun mkBlock label = Block.T {
         args = Vector.new0 (),
         label = label,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainBlock = mkBlock mainLabel
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

      fun noOpBlockF b = NONE

      val newLabel = Label.fromString "newLabel"
      fun changeNameBlockF b = SOME (mkBlock newLabel)

      fun getUniqueBlockLabel (Program.T {functions, ...}) = let
         val _ = assert (List.length functions = 1, "expect unique function")
         val func = List.first functions
         val blocks = Function.blocks func
         val _ = assert (Vector.length blocks = 1, "expect unique block")
         val block = Vector.first blocks
      in
         Block.label block
      end


      val p1' = PreFlatten.mapBlocks (p1, noOpBlockF)
      val _ = assert (Label.equals (getUniqueBlockLabel p1', mainLabel),
                      "expect original label")

      val p1'' = PreFlatten.mapBlocks (p1, changeNameBlockF)

      val _ = assert (Label.equals (getUniqueBlockLabel p1'', newLabel),
                      "expect new label")

      val _ = print "Test 14 passed\n"
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


      (* This surprising behavior is because `Type.tuple` flattens through
      single-element arguments *)
      val _ = print "Test 6b: flattening a singleton tuple (regular ctor)\n"
      val tSingletonTuple = Type.tuple (Vector.new1 t1)
      val resSingletonTuple = PreFlatten.flattenTupleVar (v, tSingletonTuple)
      val _ = case resSingletonTuple of
                  NONE => ()
                | SOME inner => printFail "unexpected flatten"

     
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

   (* Test 9a: buildBindBlock with BindCon *)
   val _ = let
      val _ = print "Test 9a: buildBindBlock with BindCon\n"
      val toVar = Var.fromString "c"
      val f1 = Var.fromString "f1"
      val con = Con.fromString "SomeCon"
      val binds = Vector.fromList [PreFlatten.BindCon {to = (toVar, Type.unit), froms = Vector.fromList [f1], con = con}]
      val targetLabel = Label.fromString "target"

      val block = PreFlatten.buildBindBlock (binds, targetLabel)
      val Block.T {statements, ...} = block

      val _ = assert (Vector.length statements = 1, "buildBindBlock should have 1 statement")

      val s0 = Vector.sub (statements, 0)
      val Statement.T {exp, var, ...} = s0
      val _ =
         case var of
            SOME v => assert (Var.equals (v, toVar), "statement var mismatch")
          | NONE => (print "statement should have a var\n"; OS.Process.exit OS.Process.failure)

      val _ =
         case exp of
            Exp.ConApp {args, con = con', ...} =>
               let
                  val _ = assert (Vector.length args = 1, "ConApp exp should have 1 arg")
                  val _ = assert (Var.equals (Vector.sub (args, 0), f1), "ConApp arg 1 mismatch")
                  val _ = assert (Con.equals (con, con'), "ConApp con mismatch")
               in () end
          | _ => (print "exp should be a ConApp\n"; OS.Process.exit OS.Process.failure)

      val _ = print "Test 9a passed\n"
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
         args = Vector.new0 (),
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

      val res = PreFlatten.buildFlattenedFunction
                    (f, Vector.fromList [PreFlatten.Preserve,
                                         PreFlatten.FlattenTuple])
      val {args, blocks, start,
           name = resName, ...} = Function.dest res
      val _ = assert (not (Label.equals(fName,  resName)),
                      "new function must have a fresh name")
      val _ = assert (Vector.length args = 3,
                      "Flattened function should have 3 args")
      val (_, rt0) = Vector.sub (args, 0)
      val (_, rt1) = Vector.sub (args, 1)
      val (_, rt2) = Vector.sub (args, 2)
      val _ = assert (Type.equals (rt0, t1), "Arg 0 type mismatch")
      val _ = assert (Type.equals (rt1, t1), "Arg 1 type mismatch")
      val _ = assert (Type.equals (rt2, t2), "Arg 2 type mismatch")
      fun checkFreshVar (v: Var.t, _) = let
         val _ = assert (not (Var.equals (v, v1)), "v1 not renamed")
         val _ = assert (not (Var.equals (v, v2)), "v2 not renamed")
      in
         ()
      end
      val _ = Function.foreachVar (res, checkFreshVar)

      val startBlock = Vector.peek (blocks, fn b => Label.equals (Block.label b, start))
      val _ = case startBlock of
         SOME (Block.T {statements, ...}) =>
            let
               val found = Vector.exists (statements, fn Statement.T {var, ...} =>
                  case var of
                     SOME v => Var.originalName v = "v2"
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
            args = Vector.new0 (),
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
            args = Vector.new0 (),
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

   val _ = let
      (* TODO(gemini): Fix names *)
      val _ = print "Test 15_2: functionManager, disconnected\n"
      val fName = Func.fromString "f15_2"
      val fName' = Func.fromString "f15_2'"
      val l1 = Label.fromString "L15_2"
      val l1' = Label.fromString "L15_2'"
      val v1 = Var.fromString "v1"
      val t1 = Type.bool
      val v2 = Var.fromString "v2"
      val t2 = Type.unit
      val tTuple = Type.tuple (Vector.fromList [t1, t2])

      val f = Function.new {
         args = Vector.fromList [(v1, t1)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
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
      val f2 = Function.new {
         args = Vector.fromList [(v1, t1)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = l1',
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName',
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = l1'
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [f, f2],
         globals = Vector.new0 (),
         main = fName
      }

      val fm = PreFlatten.newFunctionManager p

      (* Test that we can access a function that's not reachable via DFS *)
      val _ = print "Test 15_2: access disconnected function\n"
      val fNoOp = PreFlatten.getOrCreateFunc (fm, fName',
                                              Vector.fromList [PreFlatten.Preserve])
      val _ = assert (Func.equals (fNoOp, fName'), "NoOp should return original Func.t")

      val _ = PreFlatten.destroyFunctionManager fm
      val _ = print "Test 15_2 passed\n"
   in () end

   (* Test 16: flattening through a single argument for a single-argument function (Always) *)
   val _ = let
      val _ = print "Test 16: single argument function flattening: always\n"
      val fName = Func.fromString "f16"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main16"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val p' = (case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME p' => p'
                 | NONE => printFail "Test 16 (always): flattenOnce returned NONE")
      val Program.T {functions, ...} = p'

      val _ = assert (List.length functions = 3, "Expected 3 functions in flattened program")
      
      val _ = let
         val newFunc = List.peek (functions, fn f =>
            let val name = Function.name f in
               not (Func.equals (name, fName)) andalso not (Func.equals (name, mainName))
            end)
      in
         case newFunc of
            SOME f => let
               val {args, ...} = Function.dest f
               val _ = assert (Vector.length args = 2, "Expected 2 args in flattened function")
               val (_, t0) = Vector.sub (args, 0)
               val (_, t1) = Vector.sub (args, 1)
               val _ = assert (Type.equals (t0, tBool), "Arg 0 should be bool")
               val _ = assert (Type.equals (t1, tBool), "Arg 1 should be bool")
            in () end
          | NONE => printFail "Test 16: Flattened function not found"
      end

      val _ = print "Test 16 (always) passed\n"
   in () end

   (* Test 16b: single argument function flattening: local unpack *)
   val _ = let
      val _ = print "Test 16: single argument function flattening: local unpack\n"
      val fName = Func.fromString "f16b"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main16b"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val _ = (case PreFlatten.flattenOnce (PreFlatten.FlattenForAnyUnpack, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME _ => printFail "Test 16 (local unpack): flattenOnce returned SOME, expected NONE"
                 | NONE => ())

      val _ = print "Test 16 (local unpack) passed\n"
   in () end

   (* Test 17: flattening through a single argument for a multi-argument function *)
   val _ = let
      val _ = print "Test 17: single argument flattening in multi-arg function\n"
      val fName = Func.fromString "f17"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTuple), (Var.fromString "arg2", tBool)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main17"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val y = Var.fromString "y"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      val s4 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME y}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3, s4],
         transfer = Transfer.Call {
            args = Vector.fromList [x, y],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val p' = (case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME p' => p'
                 | NONE => printFail "Test 17: flattenOnce returned NONE")
      val Program.T {functions, ...} = p'

      val _ = assert (List.length functions = 3, "Expected 3 functions in flattened program")
      
      val _ = let
         val newFunc = List.peek (functions, fn f =>
            let val name = Function.name f in
               not (Func.equals (name, fName)) andalso not (Func.equals (name, mainName))
            end)
      in
         case newFunc of
            SOME f => let
               val {args, ...} = Function.dest f
               val _ = assert (Vector.length args = 3, "Expected 3 args in flattened function")
               val (_, t0) = Vector.sub (args, 0)
               val (_, t1) = Vector.sub (args, 1)
               val (_, t2) = Vector.sub (args, 2)
               val _ = assert (Type.equals (t0, tBool), "Arg 0 should be bool")
               val _ = assert (Type.equals (t1, tBool), "Arg 1 should be bool")
               val _ = assert (Type.equals (t2, tBool), "Arg 2 should be bool")
            in () end
          | NONE => printFail "Test 17: Flattened function not found"
      end

      val _ = print "Test 17 passed\n"
   in () end

   (* Test 18: flattening through multiple arguments for a multi-argument function *)
   val _ = let
      val _ = print "Test 18: multi-argument flattening\n"
      val fName = Func.fromString "f18"
      val tBool = Type.bool
      val tTup1 = Type.tuple (Vector.fromList [tBool, tBool, tBool])
      val tTup2 = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTup1), (Var.fromString "arg2", tTup2)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main18"
      val b1 = Var.fromString "b1"
      val b2 = Var.fromString "b2"
      val b3 = Var.fromString "b3"
      val x = Var.fromString "x"
      val y = Var.fromString "y"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b2}
      val s3 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b3}
      val s4 = Statement.T {exp = Exp.Tuple (Vector.fromList [b1, b2, b3]),
                            ty = tTup1, var = SOME x}
      val s5 = Statement.T {exp = Exp.Tuple (Vector.fromList [b2, b3]), ty = tTup2, var = SOME y}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3, s4, s5],
         transfer = Transfer.Call {
            args = Vector.fromList [x, y],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val _ = printProgram ("test18", p)

      val p' = (case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME p' => p'
                 | NONE => printFail "Test 18: flattenOnce returned NONE")
      val Program.T {functions, ...} = p'

      val _ = assert (List.length functions = 3, "Expected 3 functions in flattened program")

      val _ = let
         val newFunc = List.peek (functions, fn f =>
            let val name = Function.name f in
               not (Func.equals (name, fName)) andalso not (Func.equals (name, mainName))
            end)
      in
         case newFunc of
            SOME f => let
               val {args, ...} = Function.dest f
               val _ = assert (Vector.length args = 5, "Expected 5 args in flattened function")
               val _ = Vector.foreach (args, fn (_, t) =>
                          assert (Type.equals (t, tBool), "All args should be bool"))
            in () end
          | NONE => printFail "Test 18: Flattened function not found"
      end

      val _ = print "Test 18 passed\n"
   in () end

   (* Test 19: an unflattenable call *)
   val _ = let
      val _ = print "Test 19: unflattenable call\n"
      val fName = Func.fromString "f19"
      val tBool = Type.bool
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tBool)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }
      val mainName = Func.fromString "main19"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME x}
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }
      val _ = case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                 NONE => ()
               | SOME _ => printFail "Test 19: expected NONE, but got SOME"
      val _ = print "Test 19 passed\n"
   in () end

   (* Test 20: a mixture of flattenable and unflattenable calls for the same function *)
   val _ = let
      val _ = print "Test 20: mixture of flattenable and unflattenable calls\n"
      val fName = Func.fromString "f20"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main20"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x1 = Var.fromString "x1"
      val x2 = Var.fromString "x2"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x1}
      (* x2 is NOT a tuple from a tuple expression *)
      val s4 = Statement.T {exp = Exp.unit, ty = tTuple, var = SOME x2}
      
      val lMain = Label.fromString "Lmain"
      val lCall2 = Label.fromString "Lcall2"
      
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = lMain,
         statements = Vector.fromList [s1, s2, s3, s4],
         transfer = Transfer.Call {
            args = Vector.fromList [x1],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.NonTail {cont = lCall2, handler = Handler.Caller}
         }
      }
      val call2Block = Block.T {
         args = Vector.new0 (),
         label = lCall2,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.fromList [x2],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock, call2Block],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = lMain
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }
      
      val p' = (case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME p' => p'
                 | NONE => printFail "Test 20: flattenOnce returned NONE")
      val Program.T {functions, ...} = p'
      
      (* Should have 3 functions: f, main, and f_flattened (for x1 call) *)
      val _ = assert (List.length functions = 3, "Expected 3 functions in flattened program")

      val _ = let
         val origFunc = List.peek (functions, fn f => Func.equals (Function.name f, fName))
         val newFunc = List.peek (functions, fn f =>
            let val name = Function.name f in
               not (Func.equals (name, fName)) andalso not (Func.equals (name, mainName))
            end)
      in
         case (origFunc, newFunc) of
            (SOME fOrig, SOME fNew) => let
               val {args = argsOrig, ...} = Function.dest fOrig
               val {args = argsNew, ...} = Function.dest fNew
               val _ = assert (Vector.length argsOrig = 1, "Original function should have 1 arg")
               val _ = assert (Type.equals (#2 (Vector.sub (argsOrig, 0)), tTuple),
                               "Original arg should be tuple")
               val _ = assert (Vector.length argsNew = 2, "New function should have 2 args")
               val _ = assert (Type.equals (#2 (Vector.sub (argsNew, 0)), tBool), "New arg 0 should be bool")
               val _ = assert (Type.equals (#2 (Vector.sub (argsNew, 1)), tBool), "New arg 1 should be bool")
            in () end
          | _ => printFail "Test 20: Original or new function not found"
      end

      val _ = print "Test 20 passed\n"
   in () end

   (* Test 21: a mixture of different flattening decisions for the same function *)
   val _ = let
      val _ = print "Test 21: mixture of different flattening decisions\n"
      val fName = Func.fromString "f21"
      val tBool = Type.bool
      val tTup1 = Type.tuple (Vector.fromList [tBool, tBool])
      val tTup2 = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTup1), (Var.fromString "arg2", tTup2)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main21"
      val b1 = Var.fromString "b1"
      val b2 = Var.fromString "b2"
      val b3 = Var.fromString "b3"
      val x1 = Var.fromString "x1"
      val y1 = Var.fromString "y1"
      val x2 = Var.fromString "x2"
      val y2 = Var.fromString "y2"

      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b2}
      val s3 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b3}

      val sx1 = Statement.T {exp = Exp.Tuple (Vector.fromList [b1, b2]), ty = tTup1, var = SOME x1}
      val sy1 = Statement.T {exp = Exp.unit, ty = tTup2, var = SOME y1} (* No flatten *)

      val sx2 = Statement.T {exp = Exp.unit, ty = tTup1, var = SOME x2} (* No flatten *)
      val sy2 = Statement.T {exp = Exp.Tuple (Vector.fromList [b2, b3]), ty = tTup2, var = SOME y2}

      val lMain = Label.fromString "Lmain"
      val lCall2 = Label.fromString "Lcall2"

      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = lMain,
         statements = Vector.fromList [s1, s2, s3, sx1, sy1, sx2, sy2],
         transfer = Transfer.Call {
            args = Vector.fromList [x1, y1],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.NonTail {cont = lCall2, handler = Handler.Caller}
         }
      }
      val call2Block = Block.T {
         args = Vector.new0 (),
         label = lCall2,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.fromList [x2, y2],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }

      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock, call2Block],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = lMain
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val p' = (case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME p' => p'
                 | NONE => printFail "Test 21: flattenOnce returned NONE")
      val Program.T {functions, ...} = p'

      (* Should have 4 functions: f, main, f_flat1 (for x1), f_flat2 (for y2) *)
      val _ = assert (List.length functions = 4, "Expected 4 functions in flattened program")

      val _ = let
         val origFunc = List.peek (functions, fn f => Func.equals (Function.name f, fName))
         val otherFuncs = List.keepAll (functions, fn f =>
            let val name = Function.name f in
               not (Func.equals (name, fName)) andalso not (Func.equals (name, mainName))
            end)
      in
         case (origFunc, otherFuncs) of
            (SOME fOrig, [fA, fB]) => let
               val {args = argsOrig, ...} = Function.dest fOrig
               val _ = assert (Vector.length argsOrig = 2, "Original should have 2 args")
               
               fun check (f, expected) = let
                  val {args, ...} = Function.dest f
               in
                  Vector.length args = 3
                  andalso Type.equals (#2 (Vector.sub (args, 0)), List.nth (expected, 0))
                  andalso Type.equals (#2 (Vector.sub (args, 1)), List.nth (expected, 1))
                  andalso Type.equals (#2 (Vector.sub (args, 2)), List.nth (expected, 2))
               end
               
               val sig1 = [tBool, tBool, tTup2]
               val sig2 = [tTup1, tBool, tBool]
               
               val match1 = check (fA, sig1) orelse check (fB, sig1)
               val match2 = check (fA, sig2) orelse check (fB, sig2)
               
               val _ = assert (match1, "Signature [bool, bool, tuple] not found")
               val _ = assert (match2, "Signature [tuple, bool, bool] not found")
            in () end
          | _ => printFail "Test 21: Original or new functions not found correctly"
      end

      val _ = print "Test 21 passed\n"
   in () end

   (* Test 22: Iterative flattening *)
   val _ = let
      val _ = print "Test 22: Iterative flattening\n"
      val fName = Func.fromString "f22"
      val tBool = Type.bool
      val tTupInner = Type.tuple (Vector.fromList [tBool, tBool])
      val tTupOuter = Type.tuple (Vector.fromList [tTupInner, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTupOuter)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main22"
      val b1 = Var.fromString "b1"
      val b2 = Var.fromString "b2"
      val b3 = Var.fromString "b3"
      val vInner = Var.fromString "vInner"
      val vOuter = Var.fromString "vOuter"

      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b2}
      val s3 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b3}

      val sInner = Statement.T {exp = Exp.Tuple (Vector.fromList [b1, b2]), ty = tTupInner, var = SOME vInner}
      val sOuter = Statement.T {exp = Exp.Tuple (Vector.fromList [vInner, b3]), ty = tTupOuter, var = SOME vOuter}

      val lMain = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = lMain,
         statements = Vector.fromList [s1, s2, s3, sInner, sOuter],
         transfer = Transfer.Call {
            args = Vector.fromList [vOuter],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }

      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = lMain
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      (* First, run with max-iters = 1 *)
      val _ = Control.preFlattenMaxIters := 1
      val p1 = PreFlatten.transform p
      val Program.T {functions = funcs1, ...} = p1
      
      (* Should have 3 functions: f, main, and f_flat (2 args) *)
      val _ = assert (List.length funcs1 = 3, "Expected 3 functions with max-iters=1")
      
      (* Second, run with max-iters = 2 *)
      val _ = Control.preFlattenMaxIters := 2
      val p2 = PreFlatten.transform p
      val Program.T {functions = funcs2, ...} = p2
      
      (* Should have 4 functions: f, main, f_flat, and f_flat_flat (3 args) *)
      val _ = assert (List.length funcs2 = 4, "Expected 4 functions with max-iters=2")
      
      val finalFunc = List.peek (funcs2, fn f =>
         let val {args, ...} = Function.dest f in
            Vector.length args = 3
         end)
      val _ = assert (Option.isSome finalFunc, "Expected a function with 3 arguments after 2 iterations")

      val _ = print "Test 22 passed\n"
   in () end

   val emptyProgram = let
      val dummyLabel = Func.fromString "dummy"
   in
      Program.T {datatypes=Vector.new0(),
                 functions=[],
                 globals=Vector.new0(),
                 main=dummyLabel}
   end
   (* Test 23: markConsumersInStatement and getVarConsumers *)
   val _ = let
      val _ = print "Test 23: markConsumersInStatement and getVarConsumers\n"
      val vm = PreFlatten.newVarConsumerManager emptyProgram
      val v = Var.fromString "v"
      val v_dest = Var.fromString "v_dest"
      val con = Con.fromString "C"
      
      val _ = print "Test 23a: AsUnpacked\n"
      val sSelect = Statement.T {
         exp = Exp.Select {offset = 0, tuple = v},
         ty = Type.unit,
         var = SOME v_dest
      }
      val _ = PreFlatten.markConsumersInStatement (vm, sSelect)
      val consumers1 = PreFlatten.getVarConsumers (vm, v)
      val _ = assert (List.length consumers1 = 1, "Expected 1 consumer after sSelect")
      val _ = case List.nth (consumers1, 0) of
                 PreFlatten.AsUnpacked => ()
               | _ => printFail "Expected AsUnpacked for Select"

      val _ = print "Test 23b: AsCurrent (ConApp)\n"
      val sCon = Statement.T {
         exp = Exp.ConApp {args = Vector.fromList [v], con = con},
         ty = Type.unit,
         var = SOME v_dest
      }
      val _ = PreFlatten.markConsumersInStatement (vm, sCon)
      val consumers2 = PreFlatten.getVarConsumers (vm, v)
      val _ = assert (List.length consumers2 = 2, "Expected 2 consumers after sCon")
      val _ = assert (List.exists (consumers2, fn PreFlatten.AsCurrent => true | _ => false),
                      "Expected AsCurrent in consumers")

      val _ = print "Test 23c: AsCurrent (PrimApp and Tuple)\n"
      val sPrim = Statement.T {
         exp = Exp.PrimApp {args = Vector.fromList [v], prim = Prim.MLton_equal, targs = Vector.new0 ()},
         ty = Type.unit,
         var = SOME v_dest
      }
      val _ = PreFlatten.markConsumersInStatement (vm, sPrim)
      
      val sTuple = Statement.T {
         exp = Exp.Tuple (Vector.fromList [v]),
         ty = Type.unit,
         var = SOME v_dest
      }
      val _ = PreFlatten.markConsumersInStatement (vm, sTuple)

      (* TODO(pscollins): Circle back and reconsider this test *)
      val _ = print "Test 23d: AsAlias\n"
      val v_alias = Var.fromString "v_alias"
      val sVar = Statement.T {
         exp = Exp.Var v,
         ty = Type.unit,
         var = SOME v_alias
      }
      val _ = PreFlatten.markConsumersInStatement (vm, sVar)
      val consumers3 = PreFlatten.getVarConsumers (vm, v)
      val _ = assert (List.length consumers3 = 5, "Expected 5 consumers in total")
      val _ = assert (List.exists (consumers3, fn PreFlatten.AsAlias v' => Var.equals (v', v_alias) | _ => false),
                      "Expected AsAlias v_alias in consumers")

      val _ = PreFlatten.destroyVarConsumerManager vm
      val _ = print "Test 23 passed\n"
   in () end

   (* Test 24: markConsumersInTransfer *)
   val _ = let
      val _ = print "Test 24: markConsumersInTransfer\n"
      fun mkProgramForFunc f =
         Program.T {datatypes=Vector.new0(),
                    functions=[f],
                    globals=Vector.new0(),
                    main=Function.name f}
      fun mkProgramForBlocks blocks = let
         val first = Vector.first blocks
         val func = Function.new {args = Vector.new0(),
                                  blocks = blocks,
                                  inline = InlineAttr.Auto,
                                  name = Func.newString "test",
                                  raises = NONE,
                                  returns = NONE,
                                  start = Block.label first}
      in
         mkProgramForFunc func
      end
      fun getUniqueFunc p = let
         val Program.T {functions, ...} = p
      in
         case functions of
             [f] => f
           | _ => Error.bug "bad program"
      end
      fun getFirstBlock f = let
         val blocks = Function.blocks f
      in
         Vector.first blocks
      end
      val _ = let
         val _ = print "Test 24a: Goto alias\n"
         val v1 = Var.fromString "v1"
         val v2 = Var.fromString "v2"
         val v_formal1 = Var.fromString "vf1"
         val v_formal2 = Var.fromString "vf2"
         val b1Label = Label.newString "gotoer"
         val b2Label = Label.newString "gotoee"
         val b1 = Block.T {args = Vector.new0(),
                           label = b1Label,
                           statements = Vector.new0(),
                           transfer = Transfer.Goto {args = Vector.new2 (v1, v2),
                                                     dst = b2Label}}
         val b2 = Block.T {args = Vector.new2 ((v_formal1, Type.unit),
                                             (v_formal2, Type.unit)),
                           label = b2Label,
                           statements = Vector.new0(),
                           transfer = Transfer.Bug}
         val p1 = mkProgramForBlocks (Vector.new2 (b1, b2))

         val vm1 = PreFlatten.newVarConsumerManager p1

         val tGoto = (Block.transfer b1)
         (* We expect this to record v1 -> AsAlias vf1 and v2 -> AsAlias vf2
         if L has arguments [vf1, vf2]. *)
         val _ = PreFlatten.markConsumersInTransfer (vm1, tGoto)
         val consumers1 = PreFlatten.getVarConsumers (vm1, v1)
         val _ = assert (List.exists (consumers1,
                                      fn PreFlatten.AsAlias v' => Var.equals (v', v_formal1) | _ => false),
                         "Expected AsAlias vf1 for v1 in Goto")
         val consumers2 = PreFlatten.getVarConsumers (vm1, v2)
         val _ = assert (List.exists (consumers2, fn PreFlatten.AsAlias v' => Var.equals (v', v_formal2) | _ => false),
                         "Expected AsAlias vf2 for v2 in Goto")
         val _ = PreFlatten.destroyVarConsumerManager vm1
      in
         ()
      end

      val _ = let
         val _ = print "Test 24b: Call alias\n"
         val v1 = Var.fromString "v1"
         val vf1 = Var.fromString "vf1"
         val fName = Func.newString "callee"
         val callee = Function.new {args = Vector.new1 (vf1, Type.unit),
                                   blocks = Vector.new1 (Block.T {args = Vector.new0(),
                                                                label = Label.newString "L",
                                                                statements = Vector.new0(),
                                                                transfer = Transfer.Return (Vector.new0())}),
                                   inline = InlineAttr.Auto,
                                   name = fName,
                                   raises = NONE,
                                   returns = NONE,
                                   start = Label.newString "L"}
         val callerL = Label.newString "caller"
         val callerBlock = Block.T {args = Vector.new0(),
                                    label = callerL,
                                    statements = Vector.new0(),
                                    transfer = Transfer.Call {args = Vector.new1 v1,
                                                              func = fName,
                                                              inline = InlineAttr.Auto,
                                                              return = Return.Tail}}
         val caller = Function.new {args = Vector.new0(),
                                   blocks = Vector.new1 callerBlock,
                                   inline = InlineAttr.Auto,
                                   name = Func.newString "caller",
                                   raises = NONE,
                                   returns = NONE,
                                   start = callerL}
         val p = Program.T {datatypes = Vector.new0(),
                            functions = [callee, caller],
                            globals = Vector.new0(),
                            main = Func.newString "caller"}
         val vm = PreFlatten.newVarConsumerManager p
         val tCall = Block.transfer callerBlock
         val _ = PreFlatten.markConsumersInTransfer (vm, tCall)
         val consumers = PreFlatten.getVarConsumers (vm, v1)
         val _ = assert (List.exists (consumers, fn PreFlatten.AsAlias v' => Var.equals (v', vf1) | _ => false),
                         "Expected AsAlias vf1 for v1 in Call")
         val _ = PreFlatten.destroyVarConsumerManager vm
      in
         ()
      end

      val _ = let
         val _ = print "Test 24c: Return alias\n"
         val v1 = Var.fromString "v1"
         val r1 = Var.fromString "r1"
         val fName = Func.newString "callee"
         val calleeL = Label.newString "L"
         val returnT = Transfer.Return (Vector.new1 v1)
         val callee = Function.new {args = Vector.new0(),
                                   blocks = Vector.new1 (Block.T {args = Vector.new0(),
                                                                label = calleeL,
                                                                statements = Vector.new0(),
                                                                transfer = returnT}),
                                   inline = InlineAttr.Auto,
                                   name = fName,
                                   raises = NONE,
                                   returns = SOME (Vector.new1 Type.unit),
                                   start = calleeL}
         val contL = Label.newString "cont"
         val contBlock = Block.T {args = Vector.new1 (r1, Type.unit),
                                  label = contL,
                                  statements = Vector.new0(),
                                  transfer = Transfer.Return (Vector.new0())}
         val callerL = Label.newString "caller"
         val callerBlock = Block.T {args = Vector.new0(),
                                    label = callerL,
                                    statements = Vector.new0(),
                                    transfer = Transfer.Call {args = Vector.new0(),
                                                              func = fName,
                                                              inline = InlineAttr.Auto,
                                                              return = Return.NonTail {cont = contL, handler = Handler.Caller}}}
         val caller = Function.new {args = Vector.new0(),
                                   blocks = Vector.new2 (callerBlock, contBlock),
                                   inline = InlineAttr.Auto,
                                   name = Func.newString "caller",
                                   raises = NONE,
                                   returns = NONE,
                                   start = callerL}
         val p = Program.T {datatypes = Vector.new0(),
                            functions = [callee, caller],
                            globals = Vector.new0(),
                            main = Func.newString "caller"}
         val vm = PreFlatten.newVarConsumerManager p
         val tCall = Block.transfer callerBlock
         val _ = PreFlatten.markConsumersInTransfer (vm, tCall)
         val consumers = PreFlatten.getVarConsumers (vm, v1)
         val _ = assert (List.exists (consumers, fn PreFlatten.AsAlias v' => Var.equals (v', r1) | _ => false),
                         "Expected AsAlias r1 for v1 in Return")
         val _ = PreFlatten.destroyVarConsumerManager vm
      in
         ()
      end

      val _ = let
         val _ = print "Test 24d: Multiple Return alias\n"
         val v1 = Var.fromString "v1"
         val v2 = Var.fromString "v2"
         val r1 = Var.fromString "r1"
         val fName = Func.newString "callee"
         val calleeL1 = Label.newString "L1"
         val calleeL2 = Label.newString "L2"
         val callee = Function.new {args = Vector.new0(),
                                   blocks = Vector.fromList [Block.T {args = Vector.new0(),
                                                                label = calleeL1,
                                                                statements = Vector.new0(),
                                                                transfer = Transfer.Return (Vector.new1 v1)},
                                                       Block.T {args = Vector.new0(),
                                                                label = calleeL2,
                                                                statements = Vector.new0(),
                                                                transfer = Transfer.Return (Vector.new1 v2)}],
                                   inline = InlineAttr.Auto,
                                   name = fName,
                                   raises = NONE,
                                   returns = SOME (Vector.new1 Type.unit),
                                   start = calleeL1}
         val contL = Label.newString "cont"
         val contBlock = Block.T {args = Vector.new1 (r1, Type.unit),
                                  label = contL,
                                  statements = Vector.new0(),
                                  transfer = Transfer.Return (Vector.new0())}
         val callerL = Label.newString "caller"
         val callerBlock = Block.T {args = Vector.new0(),
                                    label = callerL,
                                    statements = Vector.new0(),
                                    transfer = Transfer.Call {args = Vector.new0(),
                                                              func = fName,
                                                              inline = InlineAttr.Auto,
                                                              return = Return.NonTail {cont = contL, handler = Handler.Caller}}}
         val caller = Function.new {args = Vector.new0(),
                                   blocks = Vector.fromList [callerBlock, contBlock],
                                   inline = InlineAttr.Auto,
                                   name = Func.newString "caller",
                                   raises = NONE,
                                   returns = NONE,
                                   start = callerL}
         val p = Program.T {datatypes = Vector.new0(),
                            functions = [callee, caller],
                            globals = Vector.new0(),
                            main = Func.newString "caller"}
         val vm = PreFlatten.newVarConsumerManager p
         val tCall = Block.transfer callerBlock
         val _ = PreFlatten.markConsumersInTransfer (vm, tCall)
         
         val consumers1 = PreFlatten.getVarConsumers (vm, v1)
         val _ = assert (List.exists (consumers1, fn PreFlatten.AsAlias v' => Var.equals (v', r1) | _ => false),
                         "Expected AsAlias r1 for v1")
         
         val consumers2 = PreFlatten.getVarConsumers (vm, v2)
         val _ = assert (List.exists (consumers2, fn PreFlatten.AsAlias v' => Var.equals (v', r1) | _ => false),
                         "Expected AsAlias r1 for v2")
                         
         val _ = PreFlatten.destroyVarConsumerManager vm
      in
         ()
      end
      val _ = print "Test 24 passed\n"
   in () end

   (* Test 25: updateChoiceForPolicy *)
   val _ = let
      val _ = print "Test 25: updateChoiceForPolicy\n"
      val xs = Vector.fromList [Var.fromString "x1", Var.fromString "x2"]
      
      val _ = print "Test 25a: PreserveVar always preserved (with consumers)\n"
      val res1 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenAlways 
                   (PreFlatten.PreserveVar, [PreFlatten.AsUnpacked, PreFlatten.AsCurrent])
      val _ = case res1 of PreFlatten.PreserveVar => () | _ => printFail "25a failed"
      
      val _ = print "Test 25b: FlattenAlways flattens if possible (with consumers)\n"
      val res2 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenAlways 
                   (PreFlatten.FlattenTupleVar xs, [PreFlatten.AsCurrent])
      val _ = case res2 of PreFlatten.FlattenTupleVar _ => () | _ => printFail "25b failed"

      val _ = print "Test 25c: FlattenForAnyUnpack flattens if any AsUnpacked\n"
      val res3 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAnyUnpack 
                   (PreFlatten.FlattenTupleVar xs, [PreFlatten.AsCurrent, PreFlatten.AsUnpacked])
      val _ = case res3 of PreFlatten.FlattenTupleVar _ => () | _ => printFail "25c failed"

      val _ = print "Test 25d: FlattenForAnyUnpack preserves if only AsCurrent\n"
      val res4 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAnyUnpack 
                   (PreFlatten.FlattenTupleVar xs, [PreFlatten.AsCurrent, PreFlatten.AsCurrent])
      val _ = case res4 of PreFlatten.PreserveVar => () | _ => printFail "25d failed"

      val _ = print "Test 25e: FlattenForAnyUnpack does not flatten for empty\n"
      val res4 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAnyUnpack 
                   (PreFlatten.FlattenTupleVar xs, [])
      val _ = case res4 of PreFlatten.PreserveVar => () | _ => printFail "25d failed"

      val _ = print "Test 25 passed\n"
   in () end

   (* Test 26: newVarConsumersForProgram with all consumer types *)
   val _ = let
      val _ = print "Test 26: newVarConsumersForProgram with all consumer types\n"
      
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fName = Func.fromString "f26"
      val fArg = Var.fromString "fArg"
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(fArg, tBool)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main26"
      val vUnpacked = Var.fromString "vUnpacked"
      val vCurrent = Var.fromString "vCurrent"
      val vAlias = Var.fromString "vAlias"
      
      val s1 = Statement.T {exp = Exp.Select {offset = 0, tuple = vUnpacked}, 
                            ty = tBool, var = SOME (Var.fromString "tmp1")}
      val s2 = Statement.T {exp = Exp.Tuple (Vector.fromList [vCurrent]), 
                            ty = tTuple, var = SOME (Var.fromString "tmp2")}
      
      val lMain = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.fromList [(vUnpacked, tTuple), (vCurrent, tBool), (vAlias, tBool)],
         label = lMain,
         statements = Vector.fromList [s1, s2],
         transfer = Transfer.Call {
            args = Vector.fromList [vAlias],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }

      val mainFunction = Function.new {
         args = Vector.fromList [(vUnpacked, tTuple), (vCurrent, tBool), (vAlias, tBool)],
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = lMain
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val vm = PreFlatten.newVarConsumersForProgram p
      
      val consumersUnpacked = PreFlatten.getVarConsumers (vm, vUnpacked)
      val _ = assert (List.exists (consumersUnpacked, fn PreFlatten.AsUnpacked => true | _ => false),
                      "vUnpacked should have AsUnpacked consumer")
      
      val consumersCurrent = PreFlatten.getVarConsumers (vm, vCurrent)
      val _ = assert (List.exists (consumersCurrent, fn PreFlatten.AsCurrent => true | _ => false),
                      "vCurrent should have AsCurrent consumer")
      
      val consumersAlias = PreFlatten.getVarConsumers (vm, vAlias)
      val _ = assert (List.exists (consumersAlias, fn PreFlatten.AsAlias v' => Var.equals (v', fArg) | _ => false),
                      "vAlias should have AsAlias fArg consumer")
      
      val _ = PreFlatten.destroyVarConsumerManager vm
      val _ = print "Test 26 passed\n"
   in () end

   (* Test 27: transform with preFlattenConsumerPolicy *)
   val _ = let
      val _ = print "Test 27: transform with preFlattenConsumerPolicy\n"
      val fName = Func.fromString "f27"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main27"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      (* Case 1: preFlattenConsumerPolicy = Always *)
      val _ = Control.preFlattenMaxIters := 1
      val _ = Control.preFlattenConsumerPolicy := Control.PreFlattenConsumerPolicy.Always
      val p1 = PreFlatten.transform p
      val Program.T {functions = funcs1, ...} = p1
      val _ = assert (List.length funcs1 = 3, "Expected 3 functions with policy Always")

      (* Case 2: preFlattenConsumerPolicy = AnyUnpack *)
      val _ = Control.preFlattenConsumerPolicy := Control.PreFlattenConsumerPolicy.AnyUnpack
      val p2 = PreFlatten.transform p
      val Program.T {functions = funcs2, ...} = p2
      (* AnyUnpack should NOT flatten here because arg1 is not unpacked in fFunction *)
      val _ = assert (List.length funcs2 = 2, "Expected 2 functions with policy AnyUnpack")

      (* Case 3: preFlattenConsumerPolicy = AllUnpack *)
      val _ = Control.preFlattenConsumerPolicy := Control.PreFlattenConsumerPolicy.AllUnpack
      val p3 = PreFlatten.transform p
      val Program.T {functions = funcs3, ...} = p3
      (* AllUnpack should flatten here because arg1 has NO consumers in fFunction (vacuously all unpacked) *)
      val _ = assert (List.length funcs3 = 3, "Expected 3 functions with policy AllUnpack")

      val _ = print "Test 27 passed\n"
   in () end

   (* Test 32: transform with preFlattenResolvePolicy *)
   val _ = let
      val _ = print "Test 32: transform with preFlattenResolvePolicy\n"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])

      (* g(arg1: tuple) = #0 arg1 *)
      val gName = Func.fromString "g32"
      val gArg1 = Var.fromString "gArg1"
      val gL = Label.fromString "Lg"
      val gS = Statement.T {exp = Exp.Select {offset = 0, tuple = gArg1},
                            ty = tBool, var = SOME (Var.fromString "gTmp")}
      val gFunction = Function.new {
         args = Vector.fromList [(gArg1, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = gL,
            statements = Vector.fromList [gS],
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = gName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = gL
      }

      (* f(arg1: tuple) = g(arg1) *)
      val fName = Func.fromString "f32"
      val fArg1 = Var.fromString "fArg1"
      val fL = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(fArg1, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fL,
            statements = Vector.new0 (),
            transfer = Transfer.Call {
               args = Vector.fromList [fArg1],
               func = gName,
               inline = InlineAttr.Auto,
               return = Return.Tail
            }
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fL
      }

      (* main() = f((true, true)) *)
      val mainName = Func.fromString "main32"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [gFunction, fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val _ = Control.preFlattenMaxIters := 1
      val _ = Control.preFlattenConsumerPolicy := Control.PreFlattenConsumerPolicy.AnyUnpack

      val _ = print "Case 1: preFlattenResolvePolicy = Local (should NOT flatten f)\n"
      val _ = Control.preFlattenResolvePolicy := Control.PreFlattenResolvePolicy.Local
      val pLocal = PreFlatten.transform p
      val Program.T {functions = funcsLocal, ...} = pLocal
      val fIsFlattenedLocal = List.exists (funcsLocal, fn f => 
          let val name = Func.toString (Function.name f) in
             String.hasPrefix (name, {prefix = "f32_flat"})
          end)
      val _ = assert (not fIsFlattenedLocal, "f should NOT be flattened with Local")

      val _ = print "Case 2: preFlattenResolvePolicy = Global (SHOULD flatten f)\n"
      val _ = Control.preFlattenResolvePolicy := Control.PreFlattenResolvePolicy.Global
      val pGlobal = PreFlatten.transform p
      val Program.T {functions = funcsGlobal, ...} = pGlobal
      val fIsFlattenedGlobal = List.exists (funcsGlobal, fn f => 
          let val name = Func.toString (Function.name f) in
             String.hasPrefix (name, {prefix = "f32_flat"})
          end)
      val _ = assert (fIsFlattenedGlobal, "f SHOULD be flattened with Global")

      val _ = print "Test 32 passed\n"
   in () end

   (* Test 28: resolveAliases *)
   val _ = let
      val _ = print "Test 28: resolveAliases\n"
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val v3 = Var.fromString "v3"
      
      val assignments = [
         (v1, [PreFlatten.AsUnpacked, PreFlatten.AsAlias v2]),
         (v2, [PreFlatten.AsCurrent, PreFlatten.AsAlias v3]),
         (v3, [PreFlatten.AsCurrent])
      ]
      val vm = PreFlatten.newVarConsumerManagerFromAssignments assignments
      
      fun hasUnpacked l = List.exists (l, fn PreFlatten.AsUnpacked => true | _ => false)
      fun hasCurrent l = List.exists (l, fn PreFlatten.AsCurrent => true | _ => false)
      fun hasAlias l = List.exists (l, fn PreFlatten.AsAlias _ => true | _ => false)
      fun countCurrent l = List.length (List.keepAll (l, fn PreFlatten.AsCurrent => true | _ => false))

      val _ = print "Test 28a: DropAlias\n"
      val res1 = PreFlatten.resolveAliases (PreFlatten.DropAlias, vm) (PreFlatten.getVarConsumers (vm, v1))
      val _ = assert (hasUnpacked res1, "res1 should have AsUnpacked")
      val _ = assert (not (hasAlias res1), "res1 should not have AsAlias")
      val _ = assert (not (hasCurrent res1), "res1 should not have AsCurrent")

      val _ = print "Test 28b: UnionAlias (1-deep)\n"
      val res2 = PreFlatten.resolveAliases (PreFlatten.UnionAlias, vm) (PreFlatten.getVarConsumers (vm, v3))
      val _ = assert (hasCurrent res2, "res2 should have AsCurrent")
      val _ = assert (not (hasAlias res2), "res2 should not have AsAlias")

      val _ = print "Test 28c: UnionAlias (2-deep chain)\n"
      val res3 = PreFlatten.resolveAliases (PreFlatten.UnionAlias, vm) (PreFlatten.getVarConsumers (vm, v1))
      (* v1 -> {AsUnpacked, AsAlias v2}
         v2 -> {AsCurrent, AsAlias v3}
         v3 -> {AsCurrent}
         Result should be {AsUnpacked, AsCurrent, AsCurrent}
       *)
      val _ = assert (hasUnpacked res3, "res3 should have AsUnpacked")
      val _ = assert (countCurrent res3 = 2, "res3 should have 2 AsCurrent")
      val _ = assert (not (hasAlias res3), "res3 should not have AsAlias")

      val _ = print "Test 28d: UnionAlias (cycle)\n"
      val vCycle = Var.fromString "vCycle"
      val assignmentsCycle = [
         (vCycle, [PreFlatten.AsCurrent, PreFlatten.AsAlias vCycle])
      ]
      val vmCycle = PreFlatten.newVarConsumerManagerFromAssignments assignmentsCycle
      val resCycle = PreFlatten.resolveAliases (PreFlatten.UnionAlias, vmCycle) (PreFlatten.getVarConsumers (vmCycle, vCycle))
      val _ = assert (hasCurrent resCycle, "resCycle should have AsCurrent")
      val _ = assert (not (hasAlias resCycle), "resCycle should not have AsAlias")

      val _ = PreFlatten.destroyVarConsumerManager vm
      val _ = PreFlatten.destroyVarConsumerManager vmCycle
      val _ = print "Test 28 passed\n"
   in () end

   (* Test 29: UnionAlias in flattenOnce *)
   val _ = let
      val _ = print "Test 29: UnionAlias in flattenOnce\n"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])

      (* g(arg1: tuple) = #0 arg1 *)
      val gName = Func.fromString "g29"
      val gArg1 = Var.fromString "gArg1"
      val gL = Label.fromString "Lg"
      val gS = Statement.T {exp = Exp.Select {offset = 0, tuple = gArg1},
                            ty = tBool, var = SOME (Var.fromString "gTmp")}
      val gFunction = Function.new {
         args = Vector.fromList [(gArg1, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = gL,
            statements = Vector.fromList [gS],
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = gName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = gL
      }

      (* f(arg1: tuple) = g(arg1) *)
      val fName = Func.fromString "f29"
      val fArg1 = Var.fromString "fArg1"
      val fL = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(fArg1, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fL,
            statements = Vector.new0 (),
            transfer = Transfer.Call {
               args = Vector.fromList [fArg1],
               func = gName,
               inline = InlineAttr.Auto,
               return = Return.Tail
            }
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fL
      }

      (* main() = f((true, true)) *)
      val mainName = Func.fromString "main29"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [gFunction, fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val _ = print "Test 29a: DropAlias (should NOT flatten f)\n"
      val pDrop = (case PreFlatten.flattenOnce (PreFlatten.FlattenForAnyUnpack, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                      SOME p' => p'
                    | NONE => p)
      val Program.T {functions = funcsDrop, ...} = pDrop
      (* Should have 3 functions (g, f, main) + maybe g_flat if g was reachable and flattened.
         Wait, f calls g. If we flatten g, f's call to g changes.
         Actually, g unpacks its arg, so g will ALWAYS be flattened if its arg is a tuple from a tuple exp.
         But f's arg in main is a tuple from a tuple exp.
         If resolvePolicy = DropAlias, f's arg has only AsAlias(gArg1). So f won't be flattened.
       *)
      val fIsFlattenedDrop = List.exists (funcsDrop, fn f => 
          let val name = Func.toString (Function.name f) in
             String.hasPrefix (name, {prefix = "f29_flat"})
          end)
      val _ = assert (not fIsFlattenedDrop, "f should NOT be flattened with DropAlias")

      val _ = print "Test 29a passed\n"

      val _ = print "Test 29b: UnionAlias (SHOULD flatten f)\n"
      val pUnion = (case PreFlatten.flattenOnce (PreFlatten.FlattenForAnyUnpack, PreFlatten.UnionAlias, PreFlatten.FlattenAnyType) p of
                       SOME p' => p'
                     | NONE => printFail "Test 29b: expected SOME, got NONE")
      val Program.T {functions = funcsUnion, ...} = pUnion
      val fIsFlattenedUnion = List.exists (funcsUnion, fn f => 
          let val name = Func.toString (Function.name f) in
             String.hasPrefix (name, {prefix = "f29_flat"})
          end)
      val _ = assert (fIsFlattenedUnion, "f SHOULD be flattened with UnionAlias")

      val _ = print "Test 29 passed\n"
   in () end

   (* Test 30: updateChoiceForPolicy with FlattenForAllUnpack *)
   val _ = let
      val _ = print "Test 30: updateChoiceForPolicy with FlattenForAllUnpack\n"
      val xs = Vector.fromList [Var.fromString "x1", Var.fromString "x2"]
      
      val _ = print "Test 30a: FlattenForAllUnpack flattens if all are AsUnpacked\n"
      val res1 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAllUnpack 
                   (PreFlatten.FlattenTupleVar xs, [PreFlatten.AsUnpacked, PreFlatten.AsUnpacked])
      val _ = case res1 of PreFlatten.FlattenTupleVar _ => () | _ => printFail "30a failed"

      val _ = print "Test 30a2: FlattenForAllUnpack flattens for empty users\n"
      val res1 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAllUnpack 
                   (PreFlatten.FlattenTupleVar xs, [])
      val _ = case res1 of PreFlatten.FlattenTupleVar _ => () | _ => printFail "30a failed"

      val _ = print "Test 30b: FlattenForAllUnpack flattens if empty\n"
      val res2 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAllUnpack 
                   (PreFlatten.FlattenTupleVar xs, [])
      val _ = case res2 of PreFlatten.FlattenTupleVar _ => () | _ => printFail "30b failed"

      val _ = print "Test 30c: FlattenForAllUnpack preserves if there is AsCurrent\n"
      val res3 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAllUnpack 
                   (PreFlatten.FlattenTupleVar xs, [PreFlatten.AsUnpacked, PreFlatten.AsCurrent])
      val _ = case res3 of PreFlatten.PreserveVar => () | _ => printFail "30c failed"

      val _ = print "Test 30d: FlattenForAllUnpack preserves if only AsCurrent\n"
      val res4 = PreFlatten.updateChoiceForPolicy PreFlatten.FlattenForAllUnpack 
                   (PreFlatten.FlattenTupleVar xs, [PreFlatten.AsCurrent])
      val _ = case res4 of PreFlatten.PreserveVar => () | _ => printFail "30d failed"

      val _ = print "Test 30 passed\n"
   in () end

   (* Test 31: flattenOnce with FlattenForAllUnpack *)
   val _ = let
      val _ = print "Test 31: flattenOnce with FlattenForAllUnpack\n"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])

      (* f(arg1: tuple) = #0 arg1 *)
      val fName = Func.fromString "f31"
      val fArg1 = Var.fromString "fArg1"
      val fL = Label.fromString "Lf"
      val fS = Statement.T {exp = Exp.Select {offset = 0, tuple = fArg1},
                            ty = tBool, var = SOME (Var.fromString "fTmp")}
      val fFunction = Function.new {
         args = Vector.fromList [(fArg1, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fL,
            statements = Vector.fromList [fS],
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fL
      }

      (* main() = f((true, true)) *)
      val mainName = Func.fromString "main31"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      (* Case 31a: Only AsUnpacked consumer in f. Should flatten. *)
      val _ = print "Test 31a: Only AsUnpacked consumer (should flatten)\n"
      val pFlat = (case PreFlatten.flattenOnce (PreFlatten.FlattenForAllUnpack, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                      SOME p' => p'
                    | NONE => printFail "Test 31a: expected SOME, got NONE")
      val Program.T {functions = funcsFlat, ...} = pFlat
      val fIsFlattened = List.exists (funcsFlat, fn f => 
          let val name = Func.toString (Function.name f) in
             String.hasPrefix (name, {prefix = "f31_flat"})
          end)
      val _ = assert (fIsFlattened, "f SHOULD be flattened in 31a")

      (* Case 31b: AsCurrent consumer in f. Should NOT flatten. *)
      val _ = print "Test 31b: AsCurrent consumer (should NOT flatten)\n"
      (* Modify f to have an AsCurrent consumer *)
      val fS2 = Statement.T {exp = Exp.Tuple (Vector.fromList [fArg1]),
                             ty = tTuple, var = SOME (Var.fromString "fTmp2")}
      val fFunction2 = Function.new {
         args = Vector.fromList [(fArg1, tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fL,
            statements = Vector.fromList [fS, fS2],
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fL
      }
      val p2 = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction2, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }
      val _ = case PreFlatten.flattenOnce (PreFlatten.FlattenForAllUnpack,
                                           PreFlatten.UnionAlias,
                                           PreFlatten.FlattenAnyType) p2 of
                 SOME _ => printFail "Test 31b: expected NONE, got SOME"
               | NONE => ()

      val _ = print "Test 31 passed\n"
   in () end

   (* Test 33: chooseVarsInStatement with FlattenConVar *)
   val _ = let
      val _ = print "Test 33: chooseVarsInStatement with FlattenConVar\n"
      val vcm = PreFlatten.newVarChoiceManager ()

      val v1 = Var.fromString "v1"
      val t1 = Type.bool
      val s1 = Statement.T {exp = Exp.unit, ty = t1, var = SOME v1}
      val v2 = Var.fromString "v2"
      val t2 = Type.unit
      val s2 = Statement.T {exp = Exp.unit, ty = t2, var = SOME v2}
      val _ = PreFlatten.markTypeForBinding (vcm, s1)
      val _ = PreFlatten.markTypeForBinding (vcm, s2)
      val vCon = Var.fromString "vc"
      val con = Con.fromString "C"

      val sCon = Statement.T {
         exp = Exp.ConApp {args = Vector.fromList [v1, v2], con = con},
         ty = Type.unit,
         var = SOME vCon
      }

      val _ = PreFlatten.chooseVarsInStatement (vcm, s1)
      val _ = PreFlatten.chooseVarsInStatement (vcm, s2)
      val _ = PreFlatten.chooseVarsInStatement (vcm, sCon)

      val choiceCon = PreFlatten.getVarChoice (vcm, vCon)
      val _ =
         case choiceCon of
            PreFlatten.FlattenConVar {args, con = con'} =>
               let
                  val _ = assert (Vector.length args = 2, "FlattenConVar should have 2 vars")
                  val (v1', t1') = Vector.sub (args, 0)
                  val (v2', t2') = Vector.sub (args, 1)
                  val _ = assert (Var.equals (v1', v1), "FlattenConVar var 0 mismatch")
                  val _ = assert (Type.equals (t1', t1), "FlattenConVar type 0 mismatch")
                  val _ = assert (Var.equals (v2', v2), "FlattenConVar var 1 mismatch")
                  val _ = assert (Type.equals (t2', t2), "FlattenConVar type 1 mismatch")
                  val _ = assert (Con.equals (con, con'), "FlattenConVar con mismatch")
               in () end
          | _ => (print "vc should be FlattenConVar\n"; OS.Process.exit OS.Process.failure)

      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 33 passed\n"
   in () end

   (* Test 34: newVarChoicesForProgram with FlattenConVar *)
   val _ = let
      val _ = print "Test 34: newVarChoicesForProgram with FlattenConVar\n"

      val v1 = Var.fromString "v1"
      val t1 = Type.bool
      val s1 = Statement.T {exp = Exp.unit, ty = t1, var = SOME v1}
      val v2 = Var.fromString "v2"
      val t2 = Type.unit
      val s2 = Statement.T {exp = Exp.unit, ty = t2, var = SOME v2}
      val vCon = Var.fromString "vc"
      val con = Con.fromString "C"

      val sCon = Statement.T {
         exp = Exp.ConApp {args = Vector.fromList [v1, v2], con = con},
         ty = Type.unit,
         var = SOME vCon
      }

      val mainFunc = Func.fromString "main34"
      val mainLabel = Label.fromString "L34"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.fromList [s1, s2, sCon],
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
         globals = Vector.new0 (),
         main = mainFunc
      }

      val vcm = PreFlatten.newVarChoicesForProgram p
      val choiceCon = PreFlatten.getVarChoice (vcm, vCon)
      val _ =
         case choiceCon of
            PreFlatten.FlattenConVar {args, ...} =>
               let
                  val _ = assert (Vector.length args = 2, "FlattenConVar should have 2 vars")
                  val (v1', t1') = Vector.sub (args, 0)
                  val (v2', t2') = Vector.sub (args, 1)
                  val _ = assert (Var.equals (v1', v1), "v1 mismatch")
                  val _ = assert (Type.equals (t1', t1), "t1 mismatch")
                  val _ = assert (Var.equals (v2', v2), "v2 mismatch")
                  val _ = assert (Type.equals (t2', t2), "t2 mismatch")
               in () end
          | _ => (print "vc should be FlattenConVar\n"; OS.Process.exit OS.Process.failure)

      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 34 passed\n"
   in () end

   (* Test 35: buildFlattenedFunctionWithDatatype (2-args) *)
   val _ = let
      val _ = print "Test 35: buildFlattenedFunctionWithDatatype (2-args)\n"
      val fName = Func.fromString "f35"
      val l1 = Label.fromString "L35"
      val v1 = Var.fromString "v1"
      val tCon = Type.datatypee (Tycon.fromString "T2")
      val b1 = Block.T {
         args = Vector.new0 (),
         label = l1,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f = Function.new {
         args = Vector.fromList [(v1, tCon)],
         blocks = Vector.fromList [b1],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = l1
      }

      val con = Con.fromString "C2"
      val argTys = Vector.fromList [Type.bool, Type.unit]
      val choice = PreFlatten.FlattenCon {argTys = argTys, con = con}

      val _ = print "Checking checkFlatteningChoice for datatype (2-args)\n"
      val choiceRes = PreFlatten.checkFlatteningChoice (f, Vector.fromList [choice])
      val _ = assert (choiceRes = PreFlatten.Valid, "Expected Valid for datatype flattening (2-args), got " ^ (choiceResToString choiceRes))

      val _ = print "Attempting buildFlattenedFunction for datatype (2-args)\n"
      val res = PreFlatten.buildFlattenedFunction (f, Vector.fromList [choice])
      val _ = print "Test 35 passed\n"
   in () end

   (* Test 36: buildFlattenedFunctionWithDatatype (nullary) *)
   val _ = let
      val _ = print "Test 36: buildFlattenedFunctionWithDatatype (nullary)\n"
      val fName = Func.fromString "f36"
      val l1 = Label.fromString "L36"
      val v1 = Var.fromString "v1"
      val tCon = Type.datatypee (Tycon.fromString "T0")
      val b1 = Block.T {
         args = Vector.new0 (),
         label = l1,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f = Function.new {
         args = Vector.fromList [(v1, tCon)],
         blocks = Vector.fromList [b1],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = l1
      }

      val con = Con.fromString "C0"
      val choice = PreFlatten.FlattenCon {argTys = Vector.new0 (), con = con}

      val _ = print "Checking checkFlatteningChoice for datatype (nullary)\n"
      val choiceRes = PreFlatten.checkFlatteningChoice (f, Vector.fromList [choice])
      val _ = assert (choiceRes = PreFlatten.Valid, "Expected Valid for datatype flattening (nullary), got " ^ (choiceResToString choiceRes))

      val _ = print "Attempting buildFlattenedFunction for datatype (nullary)\n"
      val res = PreFlatten.buildFlattenedFunction (f, Vector.fromList [choice])
      val _ = print "Test 36 passed\n"
   in () end

   (* Test 37: chooseVarsInStatement with FlattenConVar (nullary) *)
   val _ = let
      val _ = print "Test 37: chooseVarsInStatement with FlattenConVar (nullary)\n"
      val vcm = PreFlatten.newVarChoiceManager ()

      val vCon = Var.fromString "vc"
      val con = Con.fromString "C0"

      val sCon = Statement.T {
         exp = Exp.ConApp {args = Vector.new0 (), con = con},
         ty = Type.unit,
         var = SOME vCon
      }

      val _ = PreFlatten.chooseVarsInStatement (vcm, sCon)

      val choiceCon = PreFlatten.getVarChoice (vcm, vCon)
      val _ =
         case choiceCon of
            PreFlatten.FlattenConVar {args, con = con'} =>
               let
                  val _ = assert (Vector.length args = 0, "FlattenConVar should have 0 vars")
                  val _ = assert (Con.equals (con, con'), "FlattenConVar con mismatch")
               in () end
          | _ => (print "vc should be FlattenConVar\n"; OS.Process.exit OS.Process.failure)

      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 37 passed\n"
   in () end

   (* Test 38: choiceEqual *)
   val _ = let
      val _ = print "Test 38: choiceEqual\n"
      open PreFlatten
      val c1 = Con.fromString "C1"
      val c2 = Con.fromString "C2"
      val tys1 = Vector.fromList [Type.bool]
      val tys2 = Vector.fromList [Type.unit]

      val fc1a = FlattenCon {argTys = tys1, con = c1}
      val fc1b = FlattenCon {argTys = tys1, con = c1}
      val fc1c = FlattenCon {argTys = tys2, con = c1}
      val fc2 = FlattenCon {argTys = tys1, con = c2}

      val _ = assert (choiceEqual (Preserve, Preserve), "Preserve = Preserve")
      val _ = assert (choiceEqual (FlattenTuple, FlattenTuple), "FlattenTuple = FlattenTuple")
      val _ = assert (choiceEqual (fc1a, fc1b), "FlattenCon equal case")
      
      val _ = assert (not (choiceEqual (Preserve, FlattenTuple)), "Preserve != FlattenTuple")
      val _ = assert (not (choiceEqual (FlattenTuple, fc1a)), "FlattenTuple != FlattenCon")
      val _ = assert (not (choiceEqual (fc1a, fc2)), "FlattenCon != FlattenCon (diff con)")
      val _ = assert (not (choiceEqual (fc1a, fc1c)), "FlattenCon != FlattenCon (diff tys)")

      val _ = print "Test 38 passed\n"
   in () end

   (* Test 39: updateChoiceForAllowedTypes *)
   val _ = let
      val _ = print "Test 39: updateChoiceForAllowedTypes\n"
      val xs = Vector.fromList [Var.fromString "x1", Var.fromString "x2"]
      val args = Vector.fromList [(Var.fromString "v1", Type.bool)]
      val con = Con.fromString "C"
      
      val vcTuple = PreFlatten.FlattenTupleVar xs
      val vcCon = PreFlatten.FlattenConVar {args = args, con = con}
      val vcPreserve = PreFlatten.PreserveVar

      fun isPreserve vc = case vc of PreFlatten.PreserveVar => true | _ => false
      fun isTuple vc = case vc of PreFlatten.FlattenTupleVar _ => true | _ => false
      fun isCon vc = case vc of PreFlatten.FlattenConVar _ => true | _ => false

      val _ = print "Test 39a: FlattenAnyType\n"
      val _ = assert (isTuple (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenAnyType vcTuple), "Any: tuple should be preserved")
      val _ = assert (isCon (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenAnyType vcCon), "Any: con should be preserved")
      val _ = assert (isPreserve (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenAnyType vcPreserve), "Any: preserve should be preserved")

      val _ = print "Test 39b: FlattenOnlyTuple\n"
      val _ = assert (isTuple (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenOnlyTuple vcTuple), "OnlyTuple: tuple should be preserved")
      val _ = assert (isPreserve (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenOnlyTuple vcCon), "OnlyTuple: con should be dropped")
      val _ = assert (isPreserve (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenOnlyTuple vcPreserve), "OnlyTuple: preserve should be preserved")

      val _ = print "Test 39c: FlattenOnlyConApp\n"
      val _ = assert (isPreserve (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenOnlyConApp vcTuple), "OnlyCon: tuple should be dropped")
      val _ = assert (isCon (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenOnlyConApp vcCon), "OnlyCon: con should be preserved")
      val _ = assert (isPreserve (PreFlatten.updateChoiceForAllowedTypes PreFlatten.FlattenOnlyConApp vcPreserve), "OnlyCon: preserve should be preserved")

      val _ = print "Test 39 passed\n"
   in () end

   (* Test 40: markConsumersInTransfer with Case *)
   val _ = let
      val _ = print "Test 40: markConsumersInTransfer with Case\n"
      val vTest = Var.fromString "vTest"
      val lDefault = Label.fromString "Ldefault"
      val caseTransfer = Transfer.Case {
         cases = Cases.Con (Vector.new0 ()),
         default = SOME lDefault,
         test = vTest
      }
      
      val dummyLabel = Func.fromString "dummy"
      val p = Program.T {datatypes=Vector.new0(),
                         functions=[],
                         globals=Vector.new0(),
                         main=dummyLabel}
      val vm = PreFlatten.newVarConsumerManager p
      val _ = PreFlatten.markConsumersInTransfer (vm, caseTransfer)
      val consumers = PreFlatten.getVarConsumers (vm, vTest)
      val _ = assert (List.exists (consumers, fn PreFlatten.AsUnpacked => true | _ => false),
                      "Expected AsUnpacked for test variable in Case")
      val _ = PreFlatten.destroyVarConsumerManager vm
      val _ = print "Test 40 passed\n"
   in () end

   (* Test 41: ConApp flattening (2-ary) via flattenOnce *)
   val _ = let
      val _ = print "Test 41: ConApp flattening (2-ary) via flattenOnce\n"
      val fName = Func.fromString "f41"
      val tBool = Type.bool
      val tUnit = Type.unit
      val tCon = Type.datatypee (Tycon.fromString "T41")
      val con = Con.fromString "C41"
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tCon)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main41"
      val b1 = Var.fromString "b1"
      val u1 = Var.fromString "u1"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b1}
      val s2 = Statement.T {exp = Exp.unit, ty = tUnit, var = SOME u1}
      val s3 = Statement.T {exp = Exp.ConApp {args = Vector.fromList [b1, u1], con = con}, 
                            ty = tCon, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val p' = (case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME p' => p'
                 | NONE => printFail "Test 41: flattenOnce returned NONE")
      val Program.T {functions, ...} = p'

      val _ = assert (List.length functions = 3, "Expected 3 functions in flattened program")
      
      val _ = let
         val newFunc = List.peek (functions, fn f =>
            let val name = Function.name f in
               not (Func.equals (name, fName)) andalso not (Func.equals (name, mainName))
            end)
      in
         case newFunc of
            SOME f => let
               val {args, ...} = Function.dest f
               val _ = assert (Vector.length args = 2, "Expected 2 args in flattened function")
               val (_, t0) = Vector.sub (args, 0)
               val (_, t1) = Vector.sub (args, 1)
               val _ = assert (Type.equals (t0, tBool), "Arg 0 should be bool")
               val _ = assert (Type.equals (t1, tUnit), "Arg 1 should be unit")
            in () end
          | NONE => printFail "Test 41: Flattened function not found"
      end

      val _ = print "Test 41 passed\n"
   in () end

   (* Test 42: ConApp flattening (nullary) via flattenOnce *)
   val _ = let
      val _ = print "Test 42: ConApp flattening (nullary) via flattenOnce\n"
      val fName = Func.fromString "f42"
      val tCon = Type.datatypee (Tycon.fromString "T42")
      val con = Con.fromString "C42"
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tCon)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main42"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.ConApp {args = Vector.new0 (), con = con}, 
                            ty = tCon, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      val p' = (case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType) p of
                   SOME p' => p'
                 | NONE => printFail "Test 42: flattenOnce returned NONE")
      val Program.T {functions, ...} = p'

      val _ = assert (List.length functions = 3, "Expected 3 functions in flattened program")
      
      val _ = let
         val newFunc = List.peek (functions, fn f =>
            let val name = Function.name f in
               not (Func.equals (name, fName)) andalso not (Func.equals (name, mainName))
            end)
      in
         case newFunc of
            SOME f => let
               val {args, ...} = Function.dest f
               val _ = assert (Vector.length args = 0, "Expected 0 args in flattened function")
            in () end
          | NONE => printFail "Test 42: Flattened function not found"
      end

      val _ = print "Test 42 passed\n"
   in () end

   (* Test 43: flattenableTypesPolicy - FlattenOnlyConApp with Tuples *)
   val _ = let
      val _ = print "Test 43: flattenableTypesPolicy - FlattenOnlyConApp with Tuples\n"
      val fName = Func.fromString "f43"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main43"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      (* Should NOT flatten tuples when policy is FlattenOnlyConApp *)
      val _ = case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenOnlyConApp) p of
                 SOME _ => printFail "Test 43: expected NONE (tuples should not flatten under FlattenOnlyConApp), got SOME"
               | NONE => ()

      val _ = print "Test 43 passed\n"
   in () end

   (* Test 44: flattenableTypesPolicy - FlattenOnlyTuple with ConApps *)
   val _ = let
      val _ = print "Test 44: flattenableTypesPolicy - FlattenOnlyTuple with ConApps\n"
      val conName = Con.fromString "Ty"
      val tBool = Type.bool
      val tyconName = Tycon.fromString "T"
      val datatypes = Vector.new1 (Datatype.T {
         cons = Vector.new1 {con = conName, args = Vector.new1 tBool},
         tycon = tyconName
      })
      val tData = Type.datatypee tyconName

      val fName = Func.fromString "f44"
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.new1 (Var.fromString "arg1", tData),
         blocks = Vector.new1 (Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }),
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main44"
      val b1 = Var.fromString "b1"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b1}
      val s2 = Statement.T {exp = Exp.ConApp {args = Vector.new1 b1, con = conName}, ty = tData, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2],
         transfer = Transfer.Call {
            args = Vector.new1 x,
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.new1 mainBlock,
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = datatypes,
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      (* Should NOT flatten ConApps when policy is FlattenOnlyTuple *)
      val _ = case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenOnlyTuple) p of
                 SOME _ => printFail "Test 44: expected NONE (ConApps should not flatten under FlattenOnlyTuple), got SOME"
               | NONE => ()

      val _ = print "Test 44 passed\n"
   in () end

   (* Test 45: flattenableTypesPolicy - FlattenOnlyTuple with Tuples *)
   val _ = let
      val _ = print "Test 45: flattenableTypesPolicy - FlattenOnlyTuple with Tuples\n"
      val fName = Func.fromString "f45"
      val tBool = Type.bool
      val tTuple = Type.tuple (Vector.fromList [tBool, tBool])
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(Var.fromString "arg1", tTuple)],
         blocks = Vector.fromList [Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main45"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      (* Should flatten tuples when policy is FlattenOnlyTuple *)
      val _ = case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenOnlyTuple) p of
                 SOME _ => ()
               | NONE => printFail "Test 45: expected SOME (tuples should flatten under FlattenOnlyTuple), got NONE"

      val _ = print "Test 45 passed\n"
   in () end

   (* Test 46: flattenableTypesPolicy - FlattenOnlyConApp with ConApps *)
   val _ = let
      val _ = print "Test 46: flattenableTypesPolicy - FlattenOnlyConApp with ConApps\n"
      val conName = Con.fromString "Ty"
      val tBool = Type.bool
      val tyconName = Tycon.fromString "T"
      val datatypes = Vector.new1 (Datatype.T {
         cons = Vector.new1 {con = conName, args = Vector.new1 tBool},
         tycon = tyconName
      })
      val tData = Type.datatypee tyconName

      val fName = Func.fromString "f46"
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.new1 (Var.fromString "arg1", tData),
         blocks = Vector.new1 (Block.T {
            args = Vector.new0 (),
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }),
         inline = InlineAttr.Auto,
         name = fName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }

      val mainName = Func.fromString "main46"
      val b1 = Var.fromString "b1"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME b1}
      val s2 = Statement.T {exp = Exp.ConApp {args = Vector.new1 b1, con = conName}, ty = tData, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2],
         transfer = Transfer.Call {
            args = Vector.new1 x,
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.new1 mainBlock,
         inline = InlineAttr.Auto,
         name = mainName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainL
      }
      val p = Program.T {
         datatypes = datatypes,
         functions = [fFunction, mainFunction],
         globals = Vector.new0 (),
         main = mainName
      }

      (* Should flatten ConApps when policy is FlattenOnlyConApp *)
      val _ = case PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenOnlyConApp) p of
                 SOME _ => ()
               | NONE => printFail "Test 46: expected SOME (ConApps should not flatten under FlattenOnlyConApp), got SOME"

      val _ = print "Test 46 passed\n"
   in () end

   (* Test 47: markTypeForArgs *)
   val _ = let
      val _ = print "Test 47: markTypeForArgs\n"
      val vcm = PreFlatten.newVarChoiceManager ()
      
      val fArg = Var.fromString "fArg"
      val tBool = Type.bool
      val bArg = Var.fromString "bArg"
      val tUnit = Type.unit
      
      val fLf = Label.fromString "Lf"
      val fFunction = Function.new {
         args = Vector.fromList [(fArg, tBool)],
         blocks = Vector.fromList [Block.T {
            args = Vector.fromList [(bArg, tUnit)],
            label = fLf,
            statements = Vector.new0 (),
            transfer = Transfer.Return (Vector.new0 ())
         }],
         inline = InlineAttr.Auto,
         name = Func.fromString "f47",
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = fLf
      }
      
      val _ = PreFlatten.markTypeForArgs (vcm, fFunction)
      
      (* Test function argument via ConApp *)
      val vConF = Var.fromString "vConF"
      val conF = Con.fromString "CF"
      val sConF = Statement.T {
         exp = Exp.ConApp {args = Vector.new1 fArg, con = conF},
         ty = Type.unit,
         var = SOME vConF
      }
      val _ = PreFlatten.chooseVarsInStatement (vcm, sConF)
      val choiceF = PreFlatten.getVarChoice (vcm, vConF)
      val _ = case choiceF of
                 PreFlatten.FlattenConVar {args, ...} =>
                    let val (_, t) = Vector.sub (args, 0) in
                       assert (Type.equals (t, tBool), "fArg type mismatch")
                    end
               | _ => printFail "Expected FlattenConVar for vConF"

      (* Test block argument via ConApp *)
      val vConB = Var.fromString "vConB"
      val conB = Con.fromString "CB"
      val sConB = Statement.T {
         exp = Exp.ConApp {args = Vector.new1 bArg, con = conB},
         ty = Type.unit,
         var = SOME vConB
      }
      val _ = PreFlatten.chooseVarsInStatement (vcm, sConB)
      val choiceB = PreFlatten.getVarChoice (vcm, vConB)
      val _ = case choiceB of
                 PreFlatten.FlattenConVar {args, ...} =>
                    let val (_, t) = Vector.sub (args, 0) in
                       assert (Type.equals (t, tUnit), "bArg type mismatch")
                    end
               | _ => printFail "Expected FlattenConVar for vConB"
      
      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 47 passed\n"
   in () end

   (* Test 48: newVarChoicesForProgram ensures globals are visited *)
   val _ = let
      val _ = print "Test 48: newVarChoicesForProgram ensures globals are visited\n"
      val g1 = Var.fromString "g1"
      val tBool = Type.bool
      val gs1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME g1}
      
      val vc = Var.fromString "vc"
      val con = Con.fromString "C"
      val gs2 = Statement.T {
         exp = Exp.ConApp {args = Vector.new1 g1, con = con},
         ty = Type.unit,
         var = SOME vc
      }
      
      val mainFunc = Func.fromString "main48"
      val mainLabel = Label.fromString "L48"
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.fromList [gs1, gs2],
         main = mainFunc
      }

      val vcm = PreFlatten.newVarChoicesForProgram p
      val choice = PreFlatten.getVarChoice (vcm, vc)
      val _ = case choice of
                 PreFlatten.FlattenConVar {args, ...} =>
                    let val (_, t) = Vector.sub (args, 0) in
                       assert (Type.equals (t, tBool), "global g1 type mismatch")
                    end
               | _ => printFail "Expected FlattenConVar for vc"
      
      val _ = PreFlatten.destroyVarChoiceManager vcm
      val _ = print "Test 48 passed\n"
   in () end

   (* Test 49: transform with postFlatten *)
   val _ = let
      val _ = print "Test 49: transform with postFlatten\n"
      val mainFunc = Func.fromString "main49"
      val mainLabel = Label.fromString "L49"
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }

      val _ = Control.preFlattenPostSteps := [Control.PreFlattenPostStep.Flatten]
      val _ = PreFlatten.transform p
      val _ = print "Test 49 passed\n"
   in () end
in
end
