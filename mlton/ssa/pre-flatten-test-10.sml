local
   open Ssa
in
   (* Test 1: FlattenAnyTransfer with non-tail call preserves choice *)
   val _ = runTest ("updateChoiceForTransferPolicy - FlattenAnyTransfer + NonTailCall", fn () => let
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val parents = Vector.fromList [v1, v2]
      val choice = PreFlatten.FlattenTupleVar parents

      val func = Func.fromString "f"
      val label = Label.fromString "L"

      val nonTailCall = Transfer.Call {
         args = Vector.new0 (),
         func = func,
         inline = InlineAttr.Auto,
         return = Return.NonTail {
            cont = label,
            handler = Handler.Caller
         }
      }

      fun varChoiceEq (vc1, vc2) =
         case (vc1, vc2) of
             (PreFlatten.PreserveVar, PreFlatten.PreserveVar) => true
           | (PreFlatten.FlattenTupleVar v1, PreFlatten.FlattenTupleVar v2) =>
             Vector.equals (v1, v2, Var.equals)
           | _ => false

      val res = PreFlatten.updateChoiceForTransferPolicy (PreFlatten.FlattenAnyTransfer, nonTailCall) choice
   in
      if varChoiceEq (res, choice) then ()
      else raise TestFail "FlattenAnyTransfer + NonTailCall should preserve choice"
   end)

   (* Test 2: FlattenOnlyTailCalls with tail call preserves choice *)
   val _ = runTest ("updateChoiceForTransferPolicy - FlattenOnlyTailCalls + TailCall", fn () => let
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val parents = Vector.fromList [v1, v2]
      val choice = PreFlatten.FlattenTupleVar parents

      val func = Func.fromString "f"

      val tailCall = Transfer.Call {
         args = Vector.new0 (),
         func = func,
         inline = InlineAttr.Auto,
         return = Return.Tail
      }

      fun varChoiceEq (vc1, vc2) =
         case (vc1, vc2) of
             (PreFlatten.PreserveVar, PreFlatten.PreserveVar) => true
           | (PreFlatten.FlattenTupleVar v1, PreFlatten.FlattenTupleVar v2) =>
             Vector.equals (v1, v2, Var.equals)
           | _ => false

      val res = PreFlatten.updateChoiceForTransferPolicy (PreFlatten.FlattenOnlyTailCalls, tailCall) choice
   in
      if varChoiceEq (res, choice) then ()
      else raise TestFail "FlattenOnlyTailCalls + TailCall should preserve choice"
   end)

   (* Test 3: FlattenOnlyTailCalls with non-tail call downgrades choice *)
   val _ = runTest ("updateChoiceForTransferPolicy - FlattenOnlyTailCalls + NonTailCall", fn () => let
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val parents = Vector.fromList [v1, v2]
      val choice = PreFlatten.FlattenTupleVar parents

      val func = Func.fromString "f"
      val label = Label.fromString "L"

      val nonTailCall = Transfer.Call {
         args = Vector.new0 (),
         func = func,
         inline = InlineAttr.Auto,
         return = Return.NonTail {
            cont = label,
            handler = Handler.Caller
         }
      }

      fun varChoiceEq (vc1, vc2) =
         case (vc1, vc2) of
             (PreFlatten.PreserveVar, PreFlatten.PreserveVar) => true
           | (PreFlatten.FlattenTupleVar v1, PreFlatten.FlattenTupleVar v2) =>
             Vector.equals (v1, v2, Var.equals)
           | _ => false

      val res = PreFlatten.updateChoiceForTransferPolicy (PreFlatten.FlattenOnlyTailCalls, nonTailCall) choice
   in
      if varChoiceEq (res, PreFlatten.PreserveVar) then ()
      else raise TestFail "FlattenOnlyTailCalls + NonTailCall should downgrade choice to PreserveVar"
   end)

   (* Test 4: FlattenOnlyTailCalls with goto downgrades choice *)
   val _ = runTest ("updateChoiceForTransferPolicy - FlattenOnlyTailCalls + Goto", fn () => let
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val parents = Vector.fromList [v1, v2]
      val choice = PreFlatten.FlattenTupleVar parents

      val label = Label.fromString "L"

      val goto = Transfer.Goto {
         args = Vector.new0 (),
         dst = label
      }

      fun varChoiceEq (vc1, vc2) =
         case (vc1, vc2) of
             (PreFlatten.PreserveVar, PreFlatten.PreserveVar) => true
           | (PreFlatten.FlattenTupleVar v1, PreFlatten.FlattenTupleVar v2) =>
             Vector.equals (v1, v2, Var.equals)
           | _ => false

      val res = PreFlatten.updateChoiceForTransferPolicy (PreFlatten.FlattenOnlyTailCalls, goto) choice
   in
      if varChoiceEq (res, PreFlatten.PreserveVar) then ()
      else raise TestFail "FlattenOnlyTailCalls + Goto should downgrade choice to PreserveVar"
    end)

   fun makeTestProgram () = let
      val fName = Func.fromString "f"
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

      val mainName = Func.fromString "main"
      val t1 = Var.fromString "t1"
      val t2 = Var.fromString "t2"
      val x = Var.fromString "x"
      val s1 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t1}
      val s2 = Statement.T {exp = Exp.unit, ty = tBool, var = SOME t2}
      val s3 = Statement.T {exp = Exp.Tuple (Vector.fromList [t1, t2]), ty = tTuple, var = SOME x}
      
      val mainL = Label.fromString "Lmain"
      val contL = Label.fromString "Lcont"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainL,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Call {
            args = Vector.fromList [x],
            func = fName,
            inline = InlineAttr.Auto,
            return = Return.NonTail {
               cont = contL,
               handler = Handler.Caller
            }
         }
      }
      val contBlock = Block.T {
         args = Vector.new0 (),
         label = contL,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock, contBlock],
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
   in
      p
   end

   val _ = runTest ("flattenOnce - FlattenAnyTransfer + NonTailCall", fn () => let
      val p = makeTestProgram ()
      val res = PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType, PreFlatten.functionOnly, PreFlatten.noRecursiveFlatten, PreFlatten.FlattenAnyTransfer) p
   in
      case res of
          SOME _ => ()
        | NONE => raise TestFail "FlattenAnyTransfer + NonTailCall should flatten and return SOME"
   end)

   val _ = runTest ("flattenOnce - FlattenOnlyTailCalls + NonTailCall", fn () => let
      val p = makeTestProgram ()
      val res = PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType, PreFlatten.functionOnly, PreFlatten.noRecursiveFlatten, PreFlatten.FlattenOnlyTailCalls) p
   in
      case res of
          NONE => ()
        | SOME _ => raise TestFail "FlattenOnlyTailCalls + NonTailCall should NOT flatten and return NONE"
   end)

   val _ = runTest ("flattenOnce - FlattenOnlyTailCalls + Goto (blockOnly)", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val L1 = Label.fromString "L1"
      val a = Var.fromString "a"
      val b = Var.fromString "b"
      val v0 = Var.fromString "v0"
      val x = Var.fromString "x"
      
      val boolTy = Type.bool
      val tupleTy = Type.tuple (Vector.fromList [boolTy, boolTy])
      
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = L0,
         statements = Vector.fromList [
            Statement.T {exp = Exp.Tuple (Vector.fromList [a, b]), ty = tupleTy, var = SOME v0}
         ],
         transfer = Transfer.Goto {args = Vector.fromList [v0], dst = L1}
      }
      val L1Block = Block.T {
         args = Vector.fromList [(x, tupleTy)],
         label = L1,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      
      val mainFunction = Function.new {
         args = Vector.fromList [(a, boolTy), (b, boolTy)],
         blocks = Vector.fromList [mainBlock, L1Block],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = L0
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }

      val res = PreFlatten.flattenOnce (PreFlatten.FlattenAlways, PreFlatten.DropAlias, PreFlatten.FlattenAnyType, PreFlatten.blockOnly, PreFlatten.noRecursiveFlatten, PreFlatten.FlattenOnlyTailCalls) p
   in
      case res of
          NONE => ()
        | SOME _ => raise TestFail "FlattenOnlyTailCalls + Goto (blockOnly) should NOT flatten and return NONE"
   end)

   val _ = runTest ("transform - preFlattenTransferPolicy = TailOnly", fn () => let
      val p = makeTestProgram ()
      val _ = Control.preFlattenMaxIters := 1
      val oldPolicy = !Control.preFlattenTransferPolicy
      val _ = Control.preFlattenTransferPolicy := Control.PreFlattenTransferPolicy.TailOnly
      val p' = PreFlatten.transform p
      val _ = Control.preFlattenTransferPolicy := oldPolicy
      val Program.T {functions, ...} = p'
   in
      if List.length functions = 2 then ()
      else raise TestFail "transform with preFlattenTransferPolicy = TailOnly should not flatten non-tail call"
   end)

   val _ = runTest ("transform - preFlattenPostStepsOnly = false (flattens)", fn () => let
      val p = makeTestProgram ()
      val _ = Control.preFlattenMaxIters := 1
      val oldOnly = !Control.preFlattenPostStepsOnly
      val _ = Control.preFlattenPostStepsOnly := false
      val p' = PreFlatten.transform p
      val _ = Control.preFlattenPostStepsOnly := oldOnly
      val Program.T {functions, ...} = p'
   in
      if List.length functions = 3 then ()
      else raise TestFail "transform with preFlattenPostStepsOnly = false should flatten call and create new function"
   end)

   val _ = runTest ("transform - preFlattenPostStepsOnly = true (skips flatten, runs post steps)", fn () => let
      val p = makeTestProgram ()
      val _ = Control.preFlattenMaxIters := 1
      val oldOnly = !Control.preFlattenPostStepsOnly
      val _ = Control.preFlattenPostStepsOnly := true
      val p' = PreFlatten.transform p
      val _ = Control.preFlattenPostStepsOnly := oldOnly
      val Program.T {functions, ...} = p'
   in
      if List.length functions = 2 then ()
      else raise TestFail "transform with preFlattenPostStepsOnly = true should skip flattening and keep 2 functions"
   end)

   val _ = summarize ()
end
