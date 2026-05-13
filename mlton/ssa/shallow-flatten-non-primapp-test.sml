local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg

   fun assertSome (opt, msg) =
      case opt of
          SOME _ => ()
        | NONE => assert (false, msg ^ ": expected SOME, got NONE")

   fun assertNone (opt, msg) =
      case opt of
          SOME _ => assert (false, msg ^ ": expected NONE, got SOME")
        | NONE => ()

in
   val _ = runTest ("Test: non-PrimApp flattening (array)", fn () => let
      val v1 = Var.newString "v1"
      (* (intInf * intInf) array *)
      val ty = Type.array (Type.tuple (Vector.fromList [Type.intInf, Type.intInf]))
      
      (* x: (intInf * intInf) array = v1 *)
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = ty,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
   in
      assertSome (res, "Should flatten non-PrimApp array with flattenable type");
      let
         val ss = valOf res
         val _ = assert (Vector.length ss = 1, "Should result in exactly one statement")
         val Statement.T {ty = resTy, ...} = Vector.sub (ss, 0)
         val expectedTy = Type.tuple (Vector.fromList [Type.array Type.intInf, Type.array Type.intInf])
      in
         assert (Type.equals (resTy, expectedTy), "Resulting type should be flattened")
      end
   end)

   val _ = runTest ("Test: non-PrimApp flattening (vector)", fn () => let
      val v1 = Var.newString "v1"
      (* (intInf * intInf) vector *)
      val ty = Type.vector (Type.tuple (Vector.fromList [Type.intInf, Type.intInf]))
      
      (* x: (intInf * intInf) vector = v1 *)
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = ty,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
   in
      assertSome (res, "Should flatten non-PrimApp vector with flattenable type");
      let
         val ss = valOf res
         val _ = assert (Vector.length ss = 1, "Should result in exactly one statement")
         val Statement.T {ty = resTy, ...} = Vector.sub (ss, 0)
         val expectedTyVec = Type.tuple (Vector.fromList [Type.vector Type.intInf, Type.vector Type.intInf])
      in
         assert (Type.equals (resTy, expectedTyVec), "Resulting type should be flattened to vectors")
      end
   end)

   val _ = runTest ("Test: non-PrimApp no-flattening (not a tuple)", fn () => let
      val v1 = Var.newString "v1"
      (* intInf array *)
      val ty = Type.array Type.intInf
      
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = ty,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
   in
      assertNone (res, "Should NOT flatten non-PrimApp with non-flattenable type")
   end)

   val _ = summarize ()
end
