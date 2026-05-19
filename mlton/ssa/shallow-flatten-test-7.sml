local
   open Ssa
in
   val _ = runTest ("Test 7: set/getArgFlatteningDecision", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
      val v = Var.newString "v"
      
      (* Create a conDecision *)
      val decision = ShallowFlatten.FlattenNode (Vector.new0 ())
      
      (* Set the decision *)
      val _ = ShallowFlatten.setArgFlatteningDecision (fv, v, decision)
      
      (* Get the decision *)
      val decision' = ShallowFlatten.getArgFlatteningDecison (fv, v)
      
      (* Check equality *)
      fun decisionEquals (d1, d2) =
          case (d1, d2) of
              (ShallowFlatten.PreserveNode v1, ShallowFlatten.PreserveNode v2) =>
              Vector.length v1 = Vector.length v2 andalso
              Vector.forall2 (v1, v2, decisionEquals)
            | (ShallowFlatten.FlattenNode v1, ShallowFlatten.FlattenNode v2) =>
              Vector.length v1 = Vector.length v2 andalso
              Vector.forall2 (v1, v2, decisionEquals)
            | _ => false

      val _ = if decisionEquals (decision, decision') then ()
              else assert (false, "Decision mismatch")

      val _ = ShallowFlatten.destroyFlattenedVars fv
   in () end)
   
   val _ = summarize ()
end
