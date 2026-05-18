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
(* Test 16: flattenOnce (flattening applied) *)
   val _ = runTest ("Test 16: flattenOnce (flattening applied)", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      
      val allocPrim = Prim.Array_alloc {raw = false}
      val s1 = Statement.T {
         exp = Exp.PrimApp {args = Vector.new1 n,
                            prim = allocPrim,
                            targs = Vector.new1 tuple2Ty},
         ty = arrayTuple2Ty,
         var = SOME v1
      }
      
      val mainBlock = Block.T {
         args = Vector.fromList [(n, intTy)],
         label = L0,
         statements = Vector.new1 s1,
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
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
      val policy = ShallowFlatten.MaxWidth 3
      val res = ShallowFlatten.flattenOnce policy p
   in
      assert (Option.isSome res, "Should return SOME p' when flattening is applied")
   end)(* Test 17: shallowFlattenMaxIters *)
   val _ = runTest ("Test 17: shallowFlattenMaxIters", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      
      val allocPrim = Prim.Array_alloc {raw = false}
      val s1 = Statement.T {
         exp = Exp.PrimApp {args = Vector.new1 n,
                            prim = allocPrim,
                            targs = Vector.new1 tuple2Ty},
         ty = arrayTuple2Ty,
         var = SOME v1
      }
      
      val mainBlock = Block.T {
         args = Vector.fromList [(n, intTy)],
         label = L0,
         statements = Vector.new1 s1,
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
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
      val _ = Control.shallowFlattenMaxIters := 1
      val p' = ShallowFlatten.transform p
      val Program.T {functions = funcs', ...} = p'
      val main' = List.first funcs'
      val {blocks = blocks', ...} = Function.dest main'
      val block' = Vector.sub (blocks', 0)
      val stmts' = Block.statements block'
   in
      assert (Vector.length stmts' > 1, "Expected flattening to happen (maxIters=1)")
   end)(* Test 18: shallowFlattenPolicy *)
   val _ = runTest ("Test 18: shallowFlattenPolicy", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val intTy = Type.intInf
      val tuple3Ty = Type.tuple (Vector.fromList [intTy, intTy, intTy])
      val arrayTuple3Ty = Type.array tuple3Ty
      
      val allocPrim = Prim.Array_alloc {raw = false}
      val s1 = Statement.T {
         exp = Exp.PrimApp {args = Vector.new1 n,
                            prim = allocPrim,
                            targs = Vector.new1 tuple3Ty},
         ty = arrayTuple3Ty,
         var = SOME v1
      }
      
      val mainBlock = Block.T {
         args = Vector.fromList [(n, intTy)],
         label = L0,
         statements = Vector.new1 s1,
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
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
      (* Policy MaxWidth 4 should flatten a 3-tuple array *)
      val _ = Control.shallowFlattenPolicy := Control.ShallowFlattenPolicy.MaxWidth 4
      val p' = ShallowFlatten.transform p
      val Program.T {functions = funcs', ...} = p'
      val main' = List.first funcs'
      val {blocks = blocks', ...} = Function.dest main'
      val block' = Vector.sub (blocks', 0)
      val stmts' = Block.statements block'
   in
      assert (Vector.length stmts' > 1, "Expected flattening to happen (policy MaxWidth 4)")
   end)(* Test 19: maybeFlattenStatement (Array_toVector) *)
   val _ = runTest ("Test 19: maybeFlattenStatement (Array_toVector)", fn () => let
      val v1 = Var.fromString "v1"
      val arr = Var.fromString "arr"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val vectorTuple2Ty = Type.vector tuple2Ty

      fun primApp (p, args, targs) = 
         Exp.PrimApp {args = Vector.fromList args,
                      prim = p,
                      targs = Vector.fromList targs}

      val toVectorPrim = Prim.Array_toVector
      val s = Statement.T {
         exp = primApp (toVectorPrim, [arr], [tuple2Ty]),
         ty = vectorTuple2Ty,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatement s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_toVector should be flattenable"
      
      (* Expected:
         1. arr_a = select(arr, 0)
         2. v_a = Array_toVector['a](arr_a)
         3. arr_b = select(arr, 1)
         4. v_b = Array_toVector['b](arr_b)
         5. v1 = tuple(v_a, v_b)
      *)
      val _ = assert (Vector.length stmts = 5, "Array_toVector should flatten to 5 statements")
      val _ = assertType (Vector.sub (stmts, 0), Type.array intTy, "Array_toVector stmt 0 type")
      val _ = assertType (Vector.sub (stmts, 1), Type.array intTy, "Array_toVector stmt 1 type")
      val _ = assertType (Vector.sub (stmts, 2), Type.vector intTy, "Array_toVector stmt 2 type")
      val _ = assertType (Vector.sub (stmts, 3), Type.vector intTy, "Array_toVector stmt 3 type")
      val _ = assertType (Vector.sub (stmts, 4), 
                          Type.tuple (Vector.fromList [Type.vector intTy, Type.vector intTy]), 
                          "Array_toVector stmt 4 type")
   in () end)(* Test 20: maybeFlattenStatement (Array_alloc {raw = false}) *)
   val _ = runTest ("Test 20: maybeFlattenStatement (Array_alloc {raw = false})", fn () => let
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      
      fun primApp (p, args, targs) = 
         Exp.PrimApp {args = Vector.fromList args,
                      prim = p,
                      targs = Vector.fromList targs}

      val allocPrim = Prim.Array_alloc {raw = false}

      val s = Statement.T {
         exp = primApp (allocPrim, [n], [tuple2Ty]),
         ty = arrayTuple2Ty,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatement s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_alloc {raw = false} should be flattenable"
      
      val _ = assert (Vector.length stmts = 3, "Array_alloc {raw = false} should flatten to 3 statements")
      val _ = assertType (Vector.sub (stmts, 0), Type.array intTy, "Array_alloc stmt 0 type")
      val _ = assertType (Vector.sub (stmts, 1), Type.array intTy, "Array_alloc stmt 1 type")
      val _ = assertType (Vector.sub (stmts, 2), 
                          Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy]), 
                          "Array_alloc stmt 2 type")

      (* Verify that the generated allocs also have raw = false *)
      val _ = Vector.foreach (stmts, fn Statement.T {exp, ...} =>
         case exp of
            Exp.PrimApp {prim = Prim.Array_alloc {raw, ...}, ...} =>
               assert (not raw, "Generated Array_alloc should have raw = false")
          | _ => ())
   in () end)(* Test 21: maybeFlattenStatement (Array_sub {readBarrier = true}) *)
   val _ = runTest ("Test 21: maybeFlattenStatement (Array_sub {readBarrier = true})", fn () => let
      val v1 = Var.fromString "v1"
      val arr = Var.fromString "arr"
      val i = Var.fromString "i"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])

      fun primApp (p, args, targs) = 
         Exp.PrimApp {args = Vector.fromList args,
                      prim = p,
                      targs = Vector.fromList targs}

      val subPrim = Prim.Array_sub {readBarrier = true}
      val s = Statement.T {
         exp = primApp (subPrim, [arr, i], [tuple2Ty]),
         ty = tuple2Ty,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatement s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_sub {readBarrier = true} should be flattenable"
      
      val _ = assert (Vector.length stmts = 5, "Array_sub {readBarrier = true} should flatten to 5 statements")
      val _ = assertType (Vector.sub (stmts, 0), Type.array intTy, "Array_sub stmt 0 type")
      val _ = assertType (Vector.sub (stmts, 1), Type.array intTy, "Array_sub stmt 1 type")
      val _ = assertType (Vector.sub (stmts, 2), intTy, "Array_sub stmt 2 type")
      val _ = assertType (Vector.sub (stmts, 3), intTy, "Array_sub stmt 3 type")
      val _ = assertType (Vector.sub (stmts, 4), tuple2Ty, "Array_sub stmt 4 type")

      (* Verify that the generated subs also have readBarrier = true *)
      val _ = Vector.foreach (stmts, fn Statement.T {exp, ...} =>
         case exp of
            Exp.PrimApp {prim = Prim.Array_sub {readBarrier, ...}, ...} =>
               assert (readBarrier, "Generated Array_sub should have readBarrier = true")
          | _ => ())
   in () end)(* Test 22: maybeFlattenStatement (Array_update {writeBarrier = true}) *)
   val _ = runTest ("Test 22: maybeFlattenStatement (Array_update {writeBarrier = true})", fn () => let
      val arr = Var.fromString "arr"
      val i = Var.fromString "i"
      val x = Var.fromString "x"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      
      fun primApp (p, args, targs) = 
         Exp.PrimApp {args = Vector.fromList args,
                      prim = p,
                      targs = Vector.fromList targs}

      val updatePrim = Prim.Array_update {writeBarrier = true}
      val s = Statement.T {
         exp = primApp (updatePrim, [arr, i, x], [tuple2Ty]),
         ty = Type.unit,
         var = NONE
      }
      val res = ShallowFlatten.maybeFlattenStatement s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_update {writeBarrier = true} should be flattenable"
      
      val _ = assert (Vector.length stmts = 6, "Array_update {writeBarrier = true} should flatten to 6 statements")
      val _ = assertType (Vector.sub (stmts, 0), Type.array intTy, "Array_update stmt 0 type")
      val _ = assertType (Vector.sub (stmts, 1), Type.array intTy, "Array_update stmt 1 type")
      val _ = assertType (Vector.sub (stmts, 2), intTy, "Array_update stmt 2 type")
      val _ = assertType (Vector.sub (stmts, 3), intTy, "Array_update stmt 3 type")
      val _ = assertType (Vector.sub (stmts, 4), Type.unit, "Array_update stmt 4 type")
      val _ = assertType (Vector.sub (stmts, 5), Type.unit, "Array_update stmt 5 type")

      (* Verify that the generated updates also have writeBarrier = true *)
      val _ = Vector.foreach (stmts, fn Statement.T {exp, ...} =>
         case exp of
            Exp.PrimApp {prim = Prim.Array_update {writeBarrier, ...}, ...} =>
               assert (writeBarrier, "Generated Array_update should have writeBarrier = true")
          | _ => ())
   in () end)(* Test 23: maybeFlattenStatement (Vector_length) *)
   val _ = runTest ("Test 23: maybeFlattenStatement (Vector_length)", fn () => let
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      
      val v_vec = Var.fromString "vec"
      val v_res = Var.fromString "res"

      val s_len = Statement.T {
         exp = Exp.PrimApp {args = Vector.fromList [v_vec],
                            prim = Prim.Vector_length,
                            targs = Vector.fromList [tuple2Ty]},
         ty = intTy,
         var = SOME v_res
      }
      val res_len = ShallowFlatten.maybeFlattenStatement s_len
      val stmts_len = case res_len of
                         SOME s => s
                       | NONE => raise TestFail "Vector_length should be flattenable"
      val _ = assert (Vector.length stmts_len = 2, "Vector_length should flatten to 2 statements")
      val _ = assertType (Vector.sub (stmts_len, 0), Type.vector intTy, "Vector_length stmt 0 type")
      val _ = assertType (Vector.sub (stmts_len, 1), intTy, "Vector_length stmt 1 type")
   in () end)(* Test 24: maybeFlattenStatement (Vector_sub) *)
   val _ = runTest ("Test 24: maybeFlattenStatement (Vector_sub)", fn () => let
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      
      val v_vec = Var.fromString "vec"
      val v_i = Var.fromString "i"
      val v_res = Var.fromString "res"

      val s_sub = Statement.T {
         exp = Exp.PrimApp {args = Vector.fromList [v_vec, v_i],
                            prim = Prim.Vector_sub,
                            targs = Vector.fromList [tuple2Ty]},
         ty = tuple2Ty,
         var = SOME v_res
      }
      val res_sub = ShallowFlatten.maybeFlattenStatement s_sub
      val stmts_sub = case res_sub of
                         SOME s => s
                       | NONE => raise TestFail "Vector_sub should be flattenable"
      val _ = assert (Vector.length stmts_sub = 5, "Vector_sub should flatten to 5 statements")
      val _ = assertType (Vector.sub (stmts_sub, 0), Type.vector intTy, "Vector_sub stmt 0 type")
      val _ = assertType (Vector.sub (stmts_sub, 1), Type.vector intTy, "Vector_sub stmt 1 type")
      val _ = assertType (Vector.sub (stmts_sub, 2), intTy, "Vector_sub stmt 2 type")
      val _ = assertType (Vector.sub (stmts_sub, 3), intTy, "Vector_sub stmt 3 type")
      val _ = assertType (Vector.sub (stmts_sub, 4), tuple2Ty, "Vector_sub stmt 4 type")
   in () end)(* Test 25: Array_toVector followed by Tuple constructor *)
   val _ = runTest ("Test 25: Array_toVector followed by Tuple constructor", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val arr = Var.fromString "arr"
      val x_vec = Var.fromString "x_vec"
      val y_tuple = Var.fromString "y_tuple"
      val other = Var.fromString "other"
      
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val vectorTuple2Ty = Type.vector tuple2Ty
      val word32Ty = Type.word WordSize.word32

      val s1 = Statement.T {
         exp = Exp.PrimApp {args = Vector.new1 arr,
                            prim = Prim.Array_toVector,
                            targs = Vector.new1 tuple2Ty},
         ty = vectorTuple2Ty,
         var = SOME x_vec
      }
      
      val s2 = Statement.T {
         exp = Exp.Tuple (Vector.fromList [x_vec, other]),
         ty = Type.tuple (Vector.fromList [vectorTuple2Ty, word32Ty]),
         var = SOME y_tuple
      }

      val mainBlock = Block.T {
         args = Vector.fromList [(arr, arrayTuple2Ty), (other, word32Ty)],
         label = L0,
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
         start = L0
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val policy = ShallowFlatten.MaxWidth 2
      val res = ShallowFlatten.flattenOnce policy p
      val p' = case res of
                  SOME p' => p'
                | NONE => raise TestFail "Should have flattened"
      
      val Program.T {functions = funcs', ...} = p'
      val mainFunction' = List.first funcs'
      val {blocks = blocks', ...} = Function.dest mainFunction'
      val block' = Vector.sub (blocks', 0)
      val stmts' = Block.statements block'
      
      (* s1 should be flattened into 5 statements *)
      (* s2 should be rewritten because x_vec is now a tuple *)
      
      val _ = assert (Vector.length stmts' >= 6, "Expected at least 6 statements")
      
      (* Check the type of y_tuple in the rewritten s2 *)
      val y_stmt = Vector.last stmts'
      val Statement.T {ty = y_ty, ...} = y_stmt
      
      val expectedXty = Type.tuple (Vector.fromList [Type.vector intTy, Type.vector intTy])
      val expectedYty = Type.tuple (Vector.fromList [expectedXty, word32Ty])
      
      val _ = if Type.equals (y_ty, expectedYty) then ()
              else assert (false, "y_tuple type mismatch: " ^ (Layout.toString (Type.layout y_ty)) ^ 
                                 " expected " ^ (Layout.toString (Type.layout expectedYty)))
   in () end)
      val _ = summarize ()
end
