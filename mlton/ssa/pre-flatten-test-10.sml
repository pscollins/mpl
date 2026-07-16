local
   open Ssa
in
   val _ = let
      val _ = print "Test 65: updateFunctionChoiceForPolicy - FlattenAnyFunction\n"
      
      val fTailName = Func.fromString "fTail"
      val lTail = Label.fromString "LTail"
      val v1 = Var.fromString "v1"
      val t1 = Type.bool
      val v2 = Var.fromString "v2"
      val t2 = Type.bool
      val tTuple = Type.tuple (Vector.fromList [t1, t2])
      
      (* A tail-recursive function: calls itself with a tail call *)
      val tailBlock = Block.T {
         args = Vector.fromList [(v1, tTuple)],
         label = lTail,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.fromList [v1],
            func = fTailName,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val fTail = Function.new {
         args = Vector.fromList [(v1, tTuple)],
         blocks = Vector.fromList [tailBlock],
         inline = InlineAttr.Auto,
         name = fTailName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = lTail
      }

      (* A non-tail-recursive function: just returns *)
      val fNonRecName = Func.fromString "fNonRec"
      val lNonRec = Label.fromString "LNonRec"
      val nonRecBlock = Block.T {
         args = Vector.fromList [(v1, tTuple)],
         label = lNonRec,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val fNonRec = Function.new {
         args = Vector.fromList [(v1, tTuple)],
         blocks = Vector.fromList [nonRecBlock],
         inline = InlineAttr.Auto,
         name = fNonRecName,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = lNonRec
      }

      (* The input varChoice *)
      val testVars = Vector.fromList [v2]
      val inputChoice = PreFlatten.FlattenTupleVar testVars

      fun assertVarChoicePreserve (vc, msg) =
         case vc of
            PreFlatten.PreserveVar => ()
          | _ => printFail ("Expected PreserveVar but got other choice: " ^ msg)

      fun assertVarChoiceFlattenTuple (vc, expectedVars, msg) =
         case vc of
            PreFlatten.FlattenTupleVar parents =>
               if Vector.length parents = Vector.length expectedVars
                  andalso Vector.forall2 (parents, expectedVars, Var.equals)
               then ()
               else printFail ("Expected FlattenTupleVar with matching vars, but got mismatch: " ^ msg)
          | _ => printFail ("Expected FlattenTupleVar but got other choice: " ^ msg)

      (* 1. Under FlattenAnyFunction, both tail and non-tail recursive functions should NOT filter the choice *)
      val choice1 = PreFlatten.updateFunctionChoiceForPolicy PreFlatten.FlattenAnyFunction (fTail, inputChoice)
      val _ = assertVarChoiceFlattenTuple (choice1, testVars, "FlattenAnyFunction + fTail")

      val choice2 = PreFlatten.updateFunctionChoiceForPolicy PreFlatten.FlattenAnyFunction (fNonRec, inputChoice)
      val _ = assertVarChoiceFlattenTuple (choice2, testVars, "FlattenAnyFunction + fNonRec")

      (* 2. Under FlattenOnlyNonTai:
            - A tail-recursive function should filter the choice to PreserveVar
            - A non-tail-recursive function should keep the choice *)
      val choice3 = PreFlatten.updateFunctionChoiceForPolicy PreFlatten.FlattenOnlyNonTai (fTail, inputChoice)
      val _ = assertVarChoicePreserve (choice3, "FlattenOnlyNonTai + fTail (should be filtered to PreserveVar)")

      val choice4 = PreFlatten.updateFunctionChoiceForPolicy PreFlatten.FlattenOnlyNonTai (fNonRec, inputChoice)
      val _ = assertVarChoiceFlattenTuple (choice4, testVars, "FlattenOnlyNonTai + fNonRec")

      val _ = print "Test 65 passed\n"
   in () end
end
