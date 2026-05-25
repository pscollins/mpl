local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg
in
   (* Test 49: updateToSavedTypes - function argument types *)
   val _ = runTest ("Test 49: updateToSavedTypes - function argument types", fn () => let
      val f_name = Func.fromString "f_test_args"
      val L_start = Label.fromString "L_start"
      
      val intTy = Type.intInf
      val word32Ty = Type.word Atoms.WordSize.word32
      val boolTy = Type.bool
      
      val v_arg = Var.fromString "v_arg"
      val v_block_arg = Var.fromString "v_block_arg"
      
      val block = Block.T {
         args = Vector.fromList [(v_block_arg, intTy)],
         label = L_start,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      
      val func = Function.new {
         args = Vector.fromList [(v_arg, intTy)],
         blocks = Vector.fromList [block],
         inline = InlineAttr.Auto,
         name = f_name,
         raises = NONE,
         returns = SOME (Vector.fromList [intTy]),
         start = L_start
      }
      
      val vt = ShallowFlatten.newVarTypes ()
      (* Populate a type for all function/block arguments + returns *)
      val _ = ShallowFlatten.setVarType (vt, v_arg, word32Ty) (* new type for function arg *)
      val _ = ShallowFlatten.setVarType (vt, v_block_arg, boolTy) (* type for block arg *)
      val _ = ShallowFlatten.setReturnType (vt, f_name, SOME (Vector.fromList [word32Ty])) (* type for return *)
      
      val func' = ShallowFlatten.updateToSavedTypes (vt, func)
      
      val {args = args', ...} = Function.dest func'
      val _ = assert (Vector.length args' = 1, "Expected 1 function argument")
      val (v_arg', ty_arg') = Vector.sub (args', 0)
      val _ = assert (Var.equals (v_arg', v_arg), "Function argument variable changed")
      val _ = assert (Type.equals (ty_arg', word32Ty), "Function argument type was not updated to word32Ty")
      
      val _ = ShallowFlatten.destroyVarTypes vt
   in () end)

   (* Test 50: updateToSavedTypes - block argument types *)
   val _ = runTest ("Test 50: updateToSavedTypes - block argument types", fn () => let
      val f_name = Func.fromString "f_test_blocks"
      val L_start = Label.fromString "L_start"
      
      val intTy = Type.intInf
      val word32Ty = Type.word Atoms.WordSize.word32
      val boolTy = Type.bool
      
      val v_arg = Var.fromString "v_arg"
      val v_block_arg = Var.fromString "v_block_arg"
      
      val block = Block.T {
         args = Vector.fromList [(v_block_arg, intTy)],
         label = L_start,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      
      val func = Function.new {
         args = Vector.fromList [(v_arg, intTy)],
         blocks = Vector.fromList [block],
         inline = InlineAttr.Auto,
         name = f_name,
         raises = NONE,
         returns = SOME (Vector.fromList [intTy]),
         start = L_start
      }
      
      val vt = ShallowFlatten.newVarTypes ()
      (* Populate a type for all function/block arguments + returns *)
      val _ = ShallowFlatten.setVarType (vt, v_arg, boolTy) (* type for function arg *)
      val _ = ShallowFlatten.setVarType (vt, v_block_arg, word32Ty) (* new type for block arg *)
      val _ = ShallowFlatten.setReturnType (vt, f_name, SOME (Vector.fromList [boolTy])) (* type for return *)
      
      val func' = ShallowFlatten.updateToSavedTypes (vt, func)
      
      val blocks' = Function.blocks func'
      val _ = assert (Vector.length blocks' = 1, "Expected 1 block")
      val block' = Vector.sub (blocks', 0)
      val Block.T {args = block_args', ...} = block'
      val _ = assert (Vector.length block_args' = 1, "Expected 1 block argument")
      val (v_block_arg', ty_block_arg') = Vector.sub (block_args', 0)
      val _ = assert (Var.equals (v_block_arg', v_block_arg), "Block argument variable changed")
      val _ = assert (Type.equals (ty_block_arg', word32Ty), "Block argument type was not updated to word32Ty")
      
      val _ = ShallowFlatten.destroyVarTypes vt
   in () end)

   (* Test 51: updateToSavedTypes - function return types *)
   val _ = runTest ("Test 51: updateToSavedTypes - function return types", fn () => let
      val f_name = Func.fromString "f_test_returns"
      val L_start = Label.fromString "L_start"
      
      val intTy = Type.intInf
      val word32Ty = Type.word Atoms.WordSize.word32
      val boolTy = Type.bool
      
      val v_arg = Var.fromString "v_arg"
      val v_block_arg = Var.fromString "v_block_arg"
      
      val block = Block.T {
         args = Vector.fromList [(v_block_arg, intTy)],
         label = L_start,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      
      val func = Function.new {
         args = Vector.fromList [(v_arg, intTy)],
         blocks = Vector.fromList [block],
         inline = InlineAttr.Auto,
         name = f_name,
         raises = NONE,
         returns = SOME (Vector.fromList [intTy]),
         start = L_start
      }
      
      val vt = ShallowFlatten.newVarTypes ()
      (* Populate a type for all function/block arguments + returns *)
      val _ = ShallowFlatten.setVarType (vt, v_arg, boolTy) (* type for function arg *)
      val _ = ShallowFlatten.setVarType (vt, v_block_arg, boolTy) (* type for block arg *)
      val _ = ShallowFlatten.setReturnType (vt, f_name, SOME (Vector.fromList [word32Ty])) (* new type for return *)
      
      val func' = ShallowFlatten.updateToSavedTypes (vt, func)
      
      val {returns = returns', ...} = Function.dest func'
      val _ = case returns' of
                  SOME retTys =>
                     if Vector.length retTys = 1 andalso Type.equals (Vector.sub (retTys, 0), word32Ty) then ()
                     else assert (false, "Return type was not updated to word32Ty")
                | NONE => assert (false, "Expected SOME returns")
      
      val _ = ShallowFlatten.destroyVarTypes vt
   in () end)

   val _ = summarize ()
end
