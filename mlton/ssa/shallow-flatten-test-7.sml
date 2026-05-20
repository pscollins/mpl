local
   open Ssa
   fun assert (cond, msg) =
      if cond then () else raise TestFail msg
in
   val _ = runTest ("Test 42: Ref_deref flattening", fn () => let
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
   val _ = summarize ()
end
