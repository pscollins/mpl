local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg

   fun statementEquals (Statement.T {exp=e1, ty=t1, var=v1},
                        Statement.T {exp=e2, ty=t2, var=v2}) =
      Exp.equals (e1, e2) andalso
      Type.equals (t1, t2) andalso
      (case (v1, v2) of
          (SOME v1', SOME v2') => Var.equals (v1', v2')
        | (NONE, NONE) => true
        | _ => false)

   fun assertType (Statement.T {ty, ...}, expected, msg) =
      if Type.equals (ty, expected) then ()
      else assert (false, msg ^ ": type mismatch")
in
(* Test 1: Simple program *)
   val _ = runTest ("Test 1: Simple program", fn () => let
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

      val _ = ShallowFlatten.transform p1
   in () end)

(* Test 2: flattenProgram empty *)
   val _ = runTest ("Test 2: flattenProgram empty", fn () => let
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

      val fl = {
         updateType = fn ty => ty,
         updateStatements = fn stmts => stmts
      }

      val p' = ShallowFlatten.flattenProgram fl p
      val Program.T {datatypes, functions, globals, main} = p'
   in
      assert (Vector.length datatypes = 0, "datatypes empty");
      assert (Vector.length globals = 0, "globals empty");
      assert (length functions = 1, "functions length");
      assert (Func.equals (main, mainFunc), "main equals")
   end)

(* Test 3: flattenProgram transformations *)
   val _ = runTest ("Test 3: flattenProgram transformations", fn () => let
      val mainFunc = Func.fromString "main"
      val mainLabel = Label.fromString "L0"
      val conC = Con.fromString "C"
      val tyconT = Tycon.fromString "T"
      val dt = Datatype.T {
         cons = Vector.fromList [{args = Vector.fromList [Type.bool], con = conC}],
         tycon = tyconT
      }
      val vGlob = Var.fromString "glob"
      val vArg = Var.fromString "arg"
      val vBArg = Var.fromString "barg"
      val vStmt = Var.fromString "stmt"

      val gstmt = Statement.T {
         exp = Exp.Var vGlob,
         ty = Type.bool,
         var = SOME vGlob
      }
      val bstmt = Statement.T {
         exp = Exp.Var vStmt,
         ty = Type.bool,
         var = SOME vStmt
      }

      val mainBlock = Block.T {
         args = Vector.fromList [(vBArg, Type.bool)],
         label = mainLabel,
         statements = Vector.fromList [bstmt],
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.fromList [(vArg, Type.bool)],
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = SOME (Vector.fromList [Type.bool]),
         returns = SOME (Vector.fromList [Type.bool]),
         start = mainLabel
      }
      val p = Program.T {
         datatypes = Vector.fromList [dt],
         functions = [mainFunction],
         globals = Vector.fromList [gstmt],
         main = mainFunc
      }

      val fl = {
         updateType = fn ty => if Type.equals (ty, Type.bool) then Type.intInf else ty,
         updateStatements = fn stmts =>
            Vector.map (stmts, fn Statement.T {exp, ty, var} =>
               Statement.T {exp = exp,
                            ty = if Type.equals (ty, Type.bool) then Type.intInf else ty,
                            var = var})
      }

      val p' = ShallowFlatten.flattenProgram fl p
      val Program.T {datatypes, functions, globals, main} = p'

      (* Verify datatypes *)
      val _ = assert (Vector.length datatypes = 1, "transformed datatypes length")
      val Datatype.T {cons, tycon} = Vector.sub (datatypes, 0)
      val _ = assert (Tycon.equals (tycon, tyconT), "tycon equals")
      val _ = assert (Vector.length cons = 1, "cons length")
      val {args = dtArgs, con = dtCon} = Vector.sub (cons, 0)
      val _ = assert (Con.equals (dtCon, conC), "dtCon equals")
      val _ = assert (Vector.length dtArgs = 1, "dtArgs length")
      val _ = assert (Type.equals (Vector.sub (dtArgs, 0), Type.intInf), "dtArg transformed to intInf")

      (* Verify globals *)
      val _ = assert (Vector.length globals = 1, "transformed globals length")
      val Statement.T {ty = gTy, ...} = Vector.sub (globals, 0)
      val _ = assert (Type.equals (gTy, Type.intInf), "global transformed to intInf")

      (* Verify functions *)
      val _ = assert (length functions = 1, "transformed functions length")
      val func = hd functions
      val {args = fArgs, blocks = fBlocks, raises = fRaises, returns = fReturns, ...} = Function.dest func

      (* Verify function args *)
      val _ = assert (Vector.length fArgs = 1, "fArgs length")
      val (_, fArgTy) = Vector.sub (fArgs, 0)
      val _ = assert (Type.equals (fArgTy, Type.intInf), "fArg transformed to intInf")

      (* Verify function returns and raises *)
      val _ = case fRaises of
                 SOME ts => assert (Type.equals (Vector.sub (ts, 0), Type.intInf), "fRaises transformed")
               | NONE => assert (false, "expected SOME raises")
      val _ = case fReturns of
                 SOME ts => assert (Type.equals (Vector.sub (ts, 0), Type.intInf), "fReturns transformed")
               | NONE => assert (false, "expected SOME returns")

      (* Verify block *)
      val _ = assert (Vector.length fBlocks = 1, "fBlocks length")
      val Block.T {args = bArgs, statements = bStatements, ...} = Vector.sub (fBlocks, 0)

      (* Verify block args *)
      val _ = assert (Vector.length bArgs = 1, "bArgs length")
      val (_, bArgTy) = Vector.sub (bArgs, 0)
      val _ = assert (Type.equals (bArgTy, Type.intInf), "bArg transformed to intInf")

      (* Verify block statements *)
      val _ = assert (Vector.length bStatements = 1, "bStatements length")
      val Statement.T {ty = bTy, ...} = Vector.sub (bStatements, 0)
      val _ = assert (Type.equals (bTy, Type.intInf), "block statement transformed to intInf")
   in () end)

   val _ = summarize ()
end
