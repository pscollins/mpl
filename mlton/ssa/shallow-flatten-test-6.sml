local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg
in
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

   val _ = summarize ()
end
