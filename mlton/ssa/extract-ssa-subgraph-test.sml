structure Atoms = Atoms ()
structure Ssa = Ssa (open Atoms)
structure ExtractSsaSubgraph = ExtractSsaSubgraph (Ssa)

local
   open Ssa

   (* Helper functions for building programs *)
   fun makeProgram {datatypes, functions, globals, main} =
      Program.T {datatypes = Vector.fromList datatypes,
                 functions = functions,
                 globals = Vector.fromList globals,
                 main = main}

   fun makeFunction {name, args, start, blocks, returns} =
      Function.new {name = name,
                    args = Vector.fromList args,
                    start = start,
                    blocks = Vector.fromList blocks,
                    returns = SOME (Vector.fromList returns),
                    raises = NONE,
                    inline = InlineAttr.Auto}

   fun makeBlock {label, args, statements, transfer} =
      Block.T {label = label,
               args = Vector.fromList args,
               statements = Vector.fromList statements,
               transfer = transfer}

   val unitTy = Type.unit

   fun stmtBind (v_def, v_use) =
      Statement.T {var = SOME v_def, ty = unitTy, exp = Exp.Var v_use}

   fun stmtConst v_def =
      Statement.T {var = SOME v_def, ty = unitTy, exp = Exp.Tuple (Vector.new0 ())}
in

   (* Test 1: Basic transform no-op (existing test) *)
   val _ = runTest ("Test 1: no-op transform", fn () => let
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      val p' = ExtractSsaSubgraph.transform p
      val Program.T {main, ...} = p'
   in
      if Func.toString main = "main" then ()
      else raise TestFail "Program main function changed"
   end)

   (* Test 2: isolateSubgraph basic statement chain *)
   val _ = runTest ("Test 2: basic statement chain", fn () => let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val v3 = Var.newNoname ()
      val v4 = Var.newNoname ()
      val stmt1 = stmtBind (v2, v1)
      val stmt2 = stmtConst v4 (* unrelated statement *)
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt1, stmt2],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                              blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val isolated = ExtractSsaSubgraph.isolateSubgraph (prog, v2)
      val Program.T {functions, ...} = isolated
      val func0 = List.nth (functions, 0)
      val Block.T {statements, ...} = Vector.sub (Function.blocks func0, 0)
   in
      if Vector.length statements = 1 then ()
      else raise TestFail "Unrelated statement was not pruned"
   end)

   (* Test 3: relaxed contract - target variable is a function parameter *)
   val _ = runTest ("Test 3: target is function parameter", fn () => let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val stmt = stmtBind (v2, v1)
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [(v1, unitTy)], start = startLabel,
                              blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val isolated = ExtractSsaSubgraph.isolateSubgraph (prog, v1)
      val Program.T {functions, ...} = isolated
      val func0 = List.nth (functions, 0)
      val {args = funcArgs, ...} = Function.dest func0
   in
      if Vector.length funcArgs = 1 then ()
      else raise TestFail "Function parameter was pruned"
   end)

   (* Test 4: cross-function dataflow (signature comment example) *)
   val _ = runTest ("Test 4: cross-function dataflow", fn () => let
      (* Variables *)
      val a = Var.newNoname ()
      val b = Var.newNoname ()
      val x = Var.newNoname ()
      val y = Var.newNoname ()
      val c = Var.newNoname ()
      val z = Var.newNoname ()
      val w = Var.newNoname ()
      val res_g = Var.newNoname ()
      val unrelated = Var.newNoname ()

      (* Func names *)
      val fName = Func.newNoname ()
      val gName = Func.newNoname ()
      val hName = Func.newNoname ()
      val kName = Func.newNoname () (* completely unrelated function *)

      (* Labels *)
      val fStart = Label.newNoname ()
      val gStart = Label.newNoname ()
      val hStart = Label.newNoname ()
      val hCont = Label.newNoname ()
      val kStart = Label.newNoname ()

      (* Function f *)
      val stmt_fx = stmtBind (x, a) (* x = a + b *)
      val stmt_fy = stmtBind (y, x) (* y = x + 1 *)
      val block_f = makeBlock {
         label = fStart,
         args = [],
         statements = [stmt_fx, stmt_fy],
         transfer = Transfer.Call {
            args = Vector.fromList [y],
            func = gName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val func_f = makeFunction {name = fName, args = [(a, unitTy), (b, unitTy)], start = fStart, blocks = [block_f], returns = [unitTy]}

      (* Function g *)
      val stmt_gz = stmtBind (z, c) (* z = c * c *)
      val block_g = makeBlock {
         label = gStart,
         args = [],
         statements = [stmt_gz],
         transfer = Transfer.Return (Vector.fromList [z])
      }
      val func_g = makeFunction {name = gName, args = [(c, unitTy)], start = gStart, blocks = [block_g], returns = [unitTy]}

      (* Function h *)
      val two = Var.newNoname ()
      val stmt_two = stmtConst two
      val block_h_start = makeBlock {
         label = hStart,
         args = [],
         statements = [stmt_two],
         transfer = Transfer.Call {
            args = Vector.fromList [two],
            func = gName,
            inline = InlineAttr.Auto,
            return = Return.NonTail {cont = hCont, handler = Handler.Caller}
         }
      }
      val stmt_hw = stmtBind (w, res_g) (* w = res_g + 1 *)
      val block_h_cont = makeBlock {
         label = hCont,
         args = [(res_g, unitTy)],
         statements = [stmt_hw],
         transfer = Transfer.Return (Vector.fromList [w])
      }
      val func_h = makeFunction {name = hName, args = [], start = hStart, blocks = [block_h_start, block_h_cont], returns = [unitTy]}

      (* Function k (unrelated) *)
      val stmt_unrelated = stmtConst unrelated
      val block_k = makeBlock {
         label = kStart,
         args = [],
         statements = [stmt_unrelated],
         transfer = Transfer.Return (Vector.new0 ())
      }
      val func_k = makeFunction {name = kName, args = [], start = kStart, blocks = [block_k], returns = []}

      val prog = makeProgram {datatypes = [], functions = [func_f, func_g, func_h, func_k], globals = [], main = hName}
      
      (* Run isolateSubgraph starting at z *)
      val isolated = ExtractSsaSubgraph.isolateSubgraph (prog, z)
      val Program.T {functions = isolatedFuncs, ...} = isolated
      
      val hasFuncK = List.exists (isolatedFuncs, fn f => Func.equals (Function.name f, kName))
      val hasFuncF = List.exists (isolatedFuncs, fn f => Func.equals (Function.name f, fName))
      val hasFuncG = List.exists (isolatedFuncs, fn f => Func.equals (Function.name f, gName))
      val hasFuncH = List.exists (isolatedFuncs, fn f => Func.equals (Function.name f, hName))
   in
      if hasFuncK then raise TestFail "Unrelated function k was not pruned"
      else if not hasFuncF then raise TestFail "Dependent function f was pruned"
      else if not hasFuncG then raise TestFail "Dependent function g was pruned"
      else if not hasFuncH then raise TestFail "Dependent function h was pruned"
      else ()
   end)

   val _ = summarize ()
end
