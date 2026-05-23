local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg

   fun decisionEquals (d1, d2) =
      case (d1, d2) of
         (ShallowFlatten.PreserveNode v1, ShallowFlatten.PreserveNode v2) =>
         Vector.length v1 = Vector.length v2 andalso
         Vector.forall2 (v1, v2, decisionEquals)
       | (ShallowFlatten.FlattenNode v1, ShallowFlatten.FlattenNode v2) =>
         Vector.length v1 = Vector.length v2 andalso
         Vector.forall2 (v1, v2, decisionEquals)
       | _ => false
in
   val _ = runTest ("Test 7: set/getArgFlatteningDecision", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
      val v = Var.newString "v"
      
      (* Create a conDecision *)
      val decision = ShallowFlatten.FlattenNode (Vector.new0 ())
      
      (* Set the decision *)
      val _ = ShallowFlatten.setArgFlatteningDecision (fv, v, decision)
      
      (* Get the decision *)
      val decision' = ShallowFlatten.getArgFlatteningDecision (fv, v)
      
      (* Check equality *)
      val _ = if decisionEquals (decision, decision') then ()
              else assert (false, "Decision mismatch")

      val _ = ShallowFlatten.destroyFlattenedVars fv
   in () end)

   val _ = runTest ("Test 8: Nested array flattening", fn () => let
      val f_test = Func.fromString "f_test"
      val L_start = Label.fromString "L_start"
      
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val xyTy = Type.tuple (Vector.fromList [arrayTuple2Ty, intTy])
      
      val v_xy = Var.fromString "xy"
      val v_x = Var.fromString "x"
      val v_xlen = Var.fromString "xlen"
      
      val s1 = Statement.T {
         exp = Exp.Select {offset = 0, tuple = v_xy},
         ty = arrayTuple2Ty,
         var = SOME v_x
      }
      val s2 = Statement.T {
         exp = Exp.PrimApp {
            args = Vector.fromList [v_x],
            prim = Prim.Array_length,
            targs = Vector.fromList [tuple2Ty]
         },
         ty = intTy,
         var = SOME v_xlen
      }
      
      val block = Block.T {
         args = Vector.new0 (),
         label = L_start,
         statements = Vector.fromList [s1, s2],
         transfer = Transfer.Return (Vector.fromList [v_xlen])
      }
      
      val func = Function.new {
         args = Vector.fromList [(v_xy, xyTy)],
         blocks = Vector.fromList [block],
         inline = InlineAttr.Auto,
         name = f_test,
         raises = NONE,
         returns = SOME (Vector.fromList [intTy]),
         start = L_start
      }
      
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [func],
         globals = Vector.new0 (),
         main = f_test
      }
      
      val policy = ShallowFlatten.MaxWidth 2
      val p_opt = ShallowFlatten.flattenOnce policy p
      
      val _ = case p_opt of
         NONE => assert (false, "Should have flattened something")
       | SOME p' => let
            val Program.T {functions, ...} = p'
            val func' = case functions of
                           x :: _ => x
                         | _ => raise TestFail "No functions"
            val {args, blocks, ...} = Function.dest func'
            
            (* Check xy type *)
            val (_, ty_xy') = Vector.sub (args, 0)
            val expected_xy_ty = Type.tuple (Vector.fromList [
               Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy]),
               intTy
            ])
            val _ = assert (Type.equals (ty_xy', expected_xy_ty), "xy type should be flattened")
            
            val b = Vector.sub (blocks, 0)
            val stmts = Block.statements b
            
            (* Expected stmts:
               x = select(xy, 0)
               flatArr_0 = select(x, 0)
               xlen = Array_length[int](flatArr_0)
            *)
            val _ = assert (Vector.length stmts = 3, "Should have 3 statements")
            
            val s1' = Vector.sub (stmts, 0)
            val s2' = Vector.sub (stmts, 1)
            val s3' = Vector.sub (stmts, 2)
            
            val (s1_exp, s1_ty, s1_var) = let val Statement.T {exp, ty, var} = s1' in (exp, ty, var) end
            
            val _ = case (s1_exp, s1_ty) of
               (Exp.Select {offset=0, tuple}, ty) => (
                  assert (Var.equals (tuple, v_xy), "s1 tuple mismatch");
                  assert (Type.equals (ty, Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])), "s1 type mismatch")
               )
             | _ => assert (false, "s1 should be select")
            
            val (s2_exp, s2_var) = let val Statement.T {exp, var, ...} = s2' in (exp, var) end
            val _ = case s2_exp of
               Exp.Select {offset=0, tuple} => (
                  case s1_var of
                     SOME v_x' => assert (Var.equals (tuple, v_x'), "s2 tuple mismatch")
                   | NONE => assert (false, "s1 has no var")
               )
             | _ => assert (false, "s2 should be select")
             
            val s3_exp = let val Statement.T {exp, ...} = s3' in exp end
            val _ = case s3_exp of
               Exp.PrimApp {prim=Prim.Array_length, targs, args=args'} => (
                  assert (Vector.length targs = 1, "s3 targs length");
                  assert (Type.equals (Vector.sub (targs, 0), intTy), "s3 targ should be int");
                  assert (Vector.length args' = 1, "s3 args length");
                  case s2_var of
                     SOME v_x0 => assert (Var.equals (Vector.sub (args', 0), v_x0), "s3 arg mismatch")
                   | NONE => assert (false, "s2 has no var")
               )
             | _ => assert (false, "s3 should be Array_length")
         in () end
   in () end)

   val _ = runTest ("Test 9: Ref_deref flattening", fn () => let
      val f_test = Func.fromString "f_test"
      val L_start = Label.fromString "L_start"
      
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val refArrayTuple2Ty = Type.reff arrayTuple2Ty
      
      val v_xy = Var.fromString "xy"
      val v_x = Var.fromString "x"
      
      val s1 = Statement.T {
         exp = Exp.PrimApp {
            args = Vector.fromList [v_xy],
            prim = Prim.Ref_deref {readBarrier = false},
            targs = Vector.fromList [arrayTuple2Ty]
         },
         ty = arrayTuple2Ty,
         var = SOME v_x
      }
      
      val block = Block.T {
         args = Vector.new0 (),
         label = L_start,
         statements = Vector.fromList [s1],
         transfer = Transfer.Return (Vector.fromList [v_x])
      }
      
      val func = Function.new {
         args = Vector.fromList [(v_xy, refArrayTuple2Ty)],
         blocks = Vector.fromList [block],
         inline = InlineAttr.Auto,
         name = f_test,
         raises = NONE,
         returns = SOME (Vector.fromList [arrayTuple2Ty]),
         start = L_start
      }
      
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [func],
         globals = Vector.new0 (),
         main = f_test
      }
      
      val policy = ShallowFlatten.MaxWidth 2
      val p_opt = ShallowFlatten.flattenOnce policy p
      
      val _ = case p_opt of
         NONE => assert (false, "Should have flattened something")
       | SOME p' => let
            val Program.T {functions, ...} = p'
            val func' = case functions of
                           x :: _ => x
                         | _ => raise TestFail "No functions"
            val {args, blocks, ...} = Function.dest func'
            
            (* Check xy type: should be (int array * int array) ref *)
            val (_, ty_xy') = Vector.sub (args, 0)
            val expected_inner_ty = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])
            val expected_xy_ty = Type.reff expected_inner_ty
            val _ = assert (Type.equals (ty_xy', expected_xy_ty), "xy type should be flattened")
            
            val b = Vector.sub (blocks, 0)
            val stmts = Block.statements b
            
            (* Expected stmts:
               x = Ref_deref(xy)
            *)
            val _ = assert (Vector.length stmts = 1, "Should have 1 statement")
            val s1' = Vector.sub (stmts, 0)
            val (s1_exp, s1_ty, s1_var) = let val Statement.T {exp, ty, var} = s1' in (exp, ty, var) end
            
            val _ = case s1_exp of
               Exp.PrimApp {prim=Prim.Ref_deref _, targs, args=args'} => (
                  assert (Vector.length targs = 1, "s1 targs length");
                  assert (Type.equals (Vector.sub (targs, 0), expected_inner_ty), "s1 targ should be flattened");
                  assert (Vector.length args' = 1, "s1 args length");
                  assert (Var.equals (Vector.sub (args', 0), v_xy), "s1 arg mismatch")
               )
             | _ => assert (false, "s1 should be Ref_deref")
             
            val _ = assert (Type.equals (s1_ty, expected_inner_ty), "s1 return type should be flattened")
         in () end
   in () end)

   val _ = runTest ("Test 10: Nested Ref_deref flattening", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val xy = Var.fromString "xy"
      val x = Var.fromString "x"
      
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val nestedTupleTy = Type.tuple (Vector.fromList [arrayTuple2Ty, intTy])
      val refNestedTupleTy = Type.reff nestedTupleTy

      val s1 = Statement.T {
         exp = Exp.PrimApp {
            args = Vector.new1 xy,
            prim = Prim.Ref_deref {readBarrier = false},
            targs = Vector.new1 nestedTupleTy
         },
         ty = nestedTupleTy,
         var = SOME x
      }

      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = L0,
         statements = Vector.new1 s1,
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new1 (xy, refNestedTupleTy),
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
      val p' = case ShallowFlatten.flattenOnce policy p of
                  SOME p' => p'
                | NONE => raise TestFail "Should have flattened"
      
      val Program.T {functions = funcs', ...} = p'
      val mainFunction' = List.first funcs'
      val {args = args', blocks = blocks', ...} = Function.dest mainFunction'
      
      (* Check xy arg type *)
      val (_, xyTy') = Vector.sub (args', 0)
      val flattenedArrayTy = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])
      val expectedNestedTy = Type.tuple (Vector.fromList [flattenedArrayTy, intTy])
      val expectedRefTy = Type.reff expectedNestedTy
      
      val _ = if Type.equals (xyTy', expectedRefTy) then ()
              else assert (false, "xy type mismatch: " ^ (Layout.toString (Type.layout xyTy')) ^
                                 " expected " ^ (Layout.toString (Type.layout expectedRefTy)))

      (* Check x statement type *)
      val block' = Vector.sub (blocks', 0)
      val stmts' = Block.statements block'
      val x_stmt = Vector.sub (stmts', 0)
      val Statement.T {exp = x_exp, ty = x_ty, ...} = x_stmt
      
      val _ = if Type.equals (x_ty, expectedNestedTy) then ()
              else assert (false, "x type mismatch: " ^ (Layout.toString (Type.layout x_ty)) ^
                                 " expected " ^ (Layout.toString (Type.layout expectedNestedTy)))

      (* Check Ref_deref targs *)
      val _ = case x_exp of
                 Exp.PrimApp {prim = Prim.Ref_deref _, targs, ...} =>
                 let
                    val targ = Vector.sub (targs, 0)
                 in
                    if Type.equals (targ, expectedNestedTy) then ()
                    else assert (false, "Ref_deref targ mismatch: " ^ (Layout.toString (Type.layout targ)) ^
                                       " expected " ^ (Layout.toString (Type.layout expectedNestedTy)))
                 end
               | _ => assert (false, "Not a PrimApp")
   in () end)

   val _ = runTest ("Test 11: Return type propagation bug", fn () => let
      val _ = Control.libTargetDir := "../../build/lib/mlton/targets/self"
      val f_test = Func.fromString "f_test"
      val L_start = Label.fromString "L_start"
      
      val intTy = Type.intInf
      val seqIndexTy = Type.word (Atoms.WordSize.seqIndex ())
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      
      val v_n = Var.fromString "n"
      val v_x = Var.fromString "x"
      
      val s0 = Statement.T {
         exp = Exp.Const (Const.word (Atoms.WordX.fromInt (1, Atoms.WordSize.seqIndex ()))),
         ty = seqIndexTy,
         var = SOME v_n
      }
      val s1 = Statement.T {
         exp = Exp.PrimApp {
            args = Vector.fromList [v_n],
            prim = Prim.Array_alloc {raw = false},
            targs = Vector.fromList [tuple2Ty]
         },
         ty = arrayTuple2Ty,
         var = SOME v_x
      }
      
      val block = Block.T {
         args = Vector.new0 (),
         label = L_start,
         statements = Vector.fromList [s0, s1],
         transfer = Transfer.Return (Vector.fromList [v_x])
      }
      
      val func = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [block],
         inline = InlineAttr.Auto,
         name = f_test,
         raises = NONE,
         returns = SOME (Vector.fromList [arrayTuple2Ty]),
         start = L_start
      }
      
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [func],
         globals = Vector.new0 (),
         main = f_test
      }
      
      val policy = ShallowFlatten.MaxWidth 2
      val p_opt = ShallowFlatten.flattenOnce policy p
      
      val _ = case p_opt of
         NONE => assert (false, "Should have flattened something")
       | SOME p' => let
            val _ = typeCheck p'
         in () end
   in () end)

   val _ = summarize ()
end
