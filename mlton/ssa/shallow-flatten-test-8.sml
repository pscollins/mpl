local
   open Ssa
in
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

   val _ = summarize ()
end
