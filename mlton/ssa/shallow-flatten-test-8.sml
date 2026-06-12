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

   val _ = Control.libTargetDir := "../../build/lib/mlton/targets/self"

   val seqIndexSize = WordSize.seqIndex ()
   val seqIndexTy = Type.word seqIndexSize
   val intTy = Type.intInf
   val word32Ty = Type.word WordSize.word32

   (* Helper to build a PrimApp expression *)
   fun primApp (p, args, targs) = 
      Exp.PrimApp {args = Vector.fromList args,
                   prim = p,
                   targs = Vector.fromList targs}
in

   (* Test 1: maybeFlattenStatementAoS on non-container statements *)
   val _ = runTest ("Test 1: maybeFlattenStatementAoS - non-container statements", fn () => let
      val v1 = Var.fromString "v1"
      val s = Statement.T {
         exp = Exp.Const (Const.IntInf 123),
         ty = Type.intInf,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatementAoS s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "non-container statement should return SOME (Vector.new1 s)"
      val _ = assert (Vector.length stmts = 1, "should be 1 statement")
      val _ = assert (statementEquals (Vector.sub (stmts, 0), s), "should equal original statement")
   in () end)

   (* Test 2: maybeFlattenStatementAoS - Array_alloc on non-tuple type *)
   val _ = runTest ("Test 2: maybeFlattenStatementAoS - Array_alloc on non-tuple type", fn () => let
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val allocPrim = Prim.Array_alloc {raw = false}
      val s = Statement.T {
         exp = primApp (allocPrim, [n], [intTy]),
         ty = Type.array intTy,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatementAoS s
      val _ = assert (Option.isNone res, "Array_alloc on non-tuple should return NONE")
   in () end)

   (* Test 3: maybeFlattenStatementAoS - Array_alloc on tuple type with mixed element types *)
   val _ = runTest ("Test 3: maybeFlattenStatementAoS - Array_alloc on mixed tuple type", fn () => let
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val mixedTupleTy = Type.tuple (Vector.fromList [intTy, word32Ty])
      val allocPrim = Prim.Array_alloc {raw = false}
      val s = Statement.T {
         exp = primApp (allocPrim, [n], [mixedTupleTy]),
         ty = Type.array mixedTupleTy,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatementAoS s
      val _ = assert (Option.isNone res, "Array_alloc on mixed tuple should return NONE")
   in () end)

   (* Test 4: maybeFlattenStatementAoS - Array_alloc on tuple of identical types (width 2) *)
   val _ = runTest ("Test 4: maybeFlattenStatementAoS - Array_alloc on identical tuple (width 2)", fn () => let
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val allocPrim = Prim.Array_alloc {raw = false}
      val s = Statement.T {
         exp = primApp (allocPrim, [n], [tuple2Ty]),
         ty = Type.array tuple2Ty,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatementAoS s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_alloc on identical tuple should return SOME"
      val _ = assert (Vector.length stmts = 2, "should return 2 statements")

      (* First statement: flatSize = n * 2 *)
      val s0 = Vector.sub (stmts, 0)
      val _ = assertType (s0, seqIndexTy, "s0 type should be seqIndexTy")
      val Statement.T {exp = e0, var = v0, ...} = s0
      val _ = assert (Option.isSome v0, "s0 should bind a variable")
      val flatSizeVar = Option.valOf v0
      val _ = case e0 of
                 Exp.PrimApp {prim = Prim.Word_mul (ws, {signed = false}), args, targs} => (
                    assert (WordSize.equals (ws, seqIndexSize), "s0 Word_mul size");
                    assert (Vector.length targs = 0, "s0 targs should be empty");
                    assert (Vector.length args = 2, "s0 args length should be 2");
                    assert (Var.equals (Vector.sub (args, 0), n), "s0 first arg should be n")
                 )
               | _ => raise TestFail "s0 should be Word_mul PrimApp"

      (* Second statement: x: 'a array = Array_alloc['a](flatSize) *)
      val s1 = Vector.sub (stmts, 1)
      val _ = assertType (s1, Type.array intTy, "s1 type should be array of element type")
      val Statement.T {exp = e1, var = v1', ...} = s1
      val _ = assert (Option.isSome v1' andalso Var.equals (Option.valOf v1', v1),
                      "s1 should bind original variable")
      val _ = case e1 of
                 Exp.PrimApp {prim = Prim.Array_alloc {raw = false}, args, targs} => (
                    assert (Vector.length args = 1 andalso Var.equals (Vector.sub (args, 0), flatSizeVar),
                            "s1 arg should be flatSizeVar");
                    assert (Vector.length targs = 1 andalso Type.equals (Vector.sub (targs, 0), intTy),
                            "s1 targ should be element type")
                 )
               | _ => raise TestFail "s1 should be Array_alloc PrimApp"
   in () end)

   (* Test 5: maybeFlattenStatementAoS - Array_alloc on tuple of identical types (width 3) *)
   val _ = runTest ("Test 5: maybeFlattenStatementAoS - Array_alloc on identical tuple (width 3)", fn () => let
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val tuple3Ty = Type.tuple (Vector.fromList [word32Ty, word32Ty, word32Ty])
      val allocPrim = Prim.Array_alloc {raw = true}
      val s = Statement.T {
         exp = primApp (allocPrim, [n], [tuple3Ty]),
         ty = Type.array tuple3Ty,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatementAoS s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_alloc on identical tuple (width 3) should return SOME"
      val _ = assert (Vector.length stmts = 2, "should return 2 statements")

      (* First statement: flatSize = n * 3 *)
      val s0 = Vector.sub (stmts, 0)
      val _ = assertType (s0, seqIndexTy, "s0 type should be seqIndexTy")
      val Statement.T {exp = e0, var = v0, ...} = s0
      val _ = assert (Option.isSome v0, "s0 should bind a variable")
      val flatSizeVar = Option.valOf v0
      val _ = case e0 of
                 Exp.PrimApp {prim = Prim.Word_mul (ws, {signed = false}), args, targs} => (
                    assert (WordSize.equals (ws, seqIndexSize), "s0 Word_mul size");
                    assert (Vector.length targs = 0, "s0 targs should be empty");
                    assert (Vector.length args = 2, "s0 args length should be 2");
                    assert (Var.equals (Vector.sub (args, 0), n), "s0 first arg should be n")
                 )
               | _ => raise TestFail "s0 should be Word_mul PrimApp"

      (* Second statement: x: 'a array = Array_alloc['a](flatSize) *)
      val s1 = Vector.sub (stmts, 1)
      val _ = assertType (s1, Type.array word32Ty, "s1 type should be array of element type")
      val Statement.T {exp = e1, var = v1', ...} = s1
      val _ = assert (Option.isSome v1' andalso Var.equals (Option.valOf v1', v1),
                      "s1 should bind original variable")
      val _ = case e1 of
                 Exp.PrimApp {prim = Prim.Array_alloc {raw = true}, args, targs} => (
                    assert (Vector.length args = 1 andalso Var.equals (Vector.sub (args, 0), flatSizeVar),
                            "s1 arg should be flatSizeVar");
                    assert (Vector.length targs = 1 andalso Type.equals (Vector.sub (targs, 0), word32Ty),
                            "s1 targ should be element type")
                 )
               | _ => raise TestFail "s1 should be Array_alloc PrimApp"
   in () end)

   val _ = summarize ()
end
