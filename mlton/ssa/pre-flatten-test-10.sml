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

   val _ = summarize ()
end
