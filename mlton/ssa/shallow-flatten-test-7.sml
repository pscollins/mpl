structure SmlString = String
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

    (* Test 52: flattenOnce - NonTail return call to function returning NONE *)
    val _ = runTest ("Test 52: flattenOnce - NonTail return call to function returning NONE", fn () => let
       val f_main = Func.fromString "f_main"
       val f_noreturn = Func.fromString "f_noreturn"
       val L_start = Label.fromString "L_start"
       val L_cont = Label.fromString "L_cont"
       val L_noreturn = Label.fromString "L_noreturn"

       val intTy = Type.intInf
       val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
       val arrayTuple2Ty = Type.array tuple2Ty
       val v_alloc = Var.fromString "v_alloc"
       val n = Var.fromString "n"

       val allocPrim = Prim.Array_alloc {raw = false}
       val s1 = Statement.T {
          exp = Exp.PrimApp {args = Vector.new1 n,
                             prim = allocPrim,
                             targs = Vector.new1 tuple2Ty},
          ty = arrayTuple2Ty,
          var = SOME v_alloc
       }

       val noreturnBlock = Block.T {
          args = Vector.new0 (),
          label = L_noreturn,
          statements = Vector.new0 (),
          transfer = Transfer.Bug
       }

       val noreturnFunction = Function.new {
          args = Vector.new0 (),
          blocks = Vector.fromList [noreturnBlock],
          inline = InlineAttr.Auto,
          name = f_noreturn,
          raises = NONE,
          returns = NONE,
          start = L_noreturn
       }

       val mainStartBlock = Block.T {
          args = Vector.fromList [(n, intTy)],
          label = L_start,
          statements = Vector.fromList [s1],
          transfer = Transfer.Call {
             args = Vector.new0 (),
             func = f_noreturn,
             inline = InlineAttr.Auto,
             return = Return.NonTail {
                cont = L_cont,
                handler = Handler.Caller
             }
          }
       }

       val mainContBlock = Block.T {
          args = Vector.new0 (),
          label = L_cont,
          statements = Vector.new0 (),
          transfer = Transfer.Return (Vector.new0 ())
        }

        val mainFunction = Function.new {
           args = Vector.new0 (),
           blocks = Vector.fromList [mainStartBlock, mainContBlock],
           inline = InlineAttr.Auto,
           name = f_main,
           raises = NONE,
           returns = SOME (Vector.new0 ()),
           start = L_start
        }

        val p = Program.T {
           datatypes = Vector.new0 (),
           functions = [noreturnFunction, mainFunction],
           globals = Vector.new0 (),
           main = f_main
        }

        val policy = ShallowFlatten.MaxWidth 3
        (* Run flattenOnce. This triggers the Option exception bug in propagation.
           Once the bug is fixed, it will succeed and return SOME p' because flattening is applied. *)
        val SOME p' = ShallowFlatten.flattenOnce policy p
        val Program.T {functions, ...} = p'

        (* Verify the flattened IR of f_main *)
        val mainFunc' = List.peek (functions, fn f => Func.equals (Function.name f, f_main))
        val _ = assert (Option.isSome mainFunc', "f_main should be present in the result")
        val f_main_dest = Function.dest (valOf mainFunc')
        val startBlock = Vector.sub (#blocks f_main_dest, 0)
        val Block.T {statements = stmts, transfer = trans, ...} = startBlock

        (* Array_alloc of a 2-tuple should flatten to 3 statements:
           v_alloc_0 = Array_alloc[int](n)
           v_alloc_1 = Array_alloc[int](n)
           v_alloc = tuple(v_alloc_0, v_alloc_1) *)
        val _ = assert (Vector.length stmts = 3, "Expected 3 statements after flattening")

        val s0 = Vector.sub (stmts, 0)
        val s1 = Vector.sub (stmts, 1)
        val s2 = Vector.sub (stmts, 2)

        val intArrTy = Type.array intTy
        val tupleArrTy = Type.tuple (Vector.fromList [intArrTy, intArrTy])

        val Statement.T {ty = ty0, ...} = s0
        val Statement.T {ty = ty1, ...} = s1
        val Statement.T {ty = ty2, ...} = s2

        val _ = assert (Type.equals (ty0, intArrTy), "First flattened statement type should be int array")
        val _ = assert (Type.equals (ty1, intArrTy), "Second flattened statement type should be int array")
        val _ = assert (Type.equals (ty2, tupleArrTy), "Third flattened statement type should be int array * int array")

        (* Verify the transfer of f_main is unchanged *)
        val _ = case trans of
                    Transfer.Call {func, return = Return.NonTail {cont, ...}, ...} =>
                       if Func.equals (func, f_noreturn) andalso Label.equals (cont, L_cont) then ()
                       else assert (false, "Transfer call target or continuation changed")
                  | _ => assert (false, "Expected Transfer.Call transfer")

        (* Verify f_noreturn has returns = NONE *)
        val noreturnFunc' = List.peek (functions, fn f => Func.equals (Function.name f, f_noreturn))
        val _ = assert (Option.isSome noreturnFunc', "f_noreturn should be present in the result")
        val f_noreturn_dest = Function.dest (valOf noreturnFunc')
        val _ = assert (Option.isNone (#returns f_noreturn_dest), "f_noreturn should still have returns = NONE")
     in () end)

    (* Test 53: flattenOnce - Array_length of tuple array block argument *)
    val _ = runTest ("Test 53: flattenOnce - Array_length of tuple array block argument", fn () => let
       val _ = Control.libTargetDir := "../../build/lib/mlton/targets/self"
       
       val f_caller = Func.fromString "f_caller"
       val f_callee = Func.fromString "f_callee"
       val L_caller_start = Label.fromString "L_caller_start"
       val L_ret = Label.fromString "L_ret"
       val L_callee_start = Label.fromString "L_callee_start"

       val intTy = Type.intInf
       val seqIndexTy = Type.word (Atoms.WordSize.seqIndex ())
       val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
       val arrayTuple2Ty = Type.array tuple2Ty
       
       val n_callee = Var.fromString "n_callee"
       val v_alloc = Var.fromString "v_alloc"
       
       val n_caller = Var.fromString "n_caller"
       val ret_val = Var.fromString "ret_val"
       val len = Var.fromString "len"

       val calleeBlock = Block.T {
          args = Vector.new0 (),
          label = L_callee_start,
          statements = Vector.fromList [
             Statement.T {
                exp = Exp.PrimApp {
                   args = Vector.new1 n_callee,
                   prim = Prim.Array_alloc {raw = false},
                   targs = Vector.new1 tuple2Ty
                },
                ty = arrayTuple2Ty,
                var = SOME v_alloc
             }
          ],
          transfer = Transfer.Return (Vector.new1 v_alloc)
       }

       val calleeFunction = Function.new {
          args = Vector.fromList [(n_callee, seqIndexTy)],
          blocks = Vector.fromList [calleeBlock],
          inline = InlineAttr.Auto,
          name = f_callee,
          raises = NONE,
          returns = SOME (Vector.fromList [arrayTuple2Ty]),
          start = L_callee_start
       }

       val callerStartBlock = Block.T {
          args = Vector.new0 (),
          label = L_caller_start,
          statements = Vector.fromList [
             Statement.T {
                exp = Exp.Const (Const.word (Atoms.WordX.fromInt (10, Atoms.WordSize.seqIndex ()))),
                ty = seqIndexTy,
                var = SOME n_caller
             }
          ],
          transfer = Transfer.Call {
             args = Vector.new1 n_caller,
             func = f_callee,
             inline = InlineAttr.Auto,
             return = Return.NonTail {
                cont = L_ret,
                handler = Handler.Caller
             }
          }
       }

       val callerRetBlock = Block.T {
          args = Vector.fromList [(ret_val, arrayTuple2Ty)],
          label = L_ret,
          statements = Vector.fromList [
             Statement.T {
                exp = Exp.PrimApp {
                   args = Vector.new1 ret_val,
                   prim = Prim.Array_length,
                   targs = Vector.new1 tuple2Ty
                },
                ty = seqIndexTy,
                var = SOME len
             }
          ],
          transfer = Transfer.Return (Vector.new0 ())
       }

       val callerFunction = Function.new {
          args = Vector.new0 (),
          blocks = Vector.fromList [callerStartBlock, callerRetBlock],
          inline = InlineAttr.Auto,
          name = f_caller,
          raises = NONE,
          returns = SOME (Vector.new0 ()),
          start = L_caller_start
       }

       val p = Program.T {
          datatypes = Vector.new0 (),
          functions = [calleeFunction, callerFunction],
          globals = Vector.new0 (),
          main = f_caller
       }

       val policy = ShallowFlatten.MaxWidth 3
       val SOME p' = ShallowFlatten.flattenOnce policy p

       (* Under the buggy compiler, this will raise a typecheck Fail exception *)
       val _ = Ssa.typeCheck p'

       (* Under a correct compiler, we assert that the IR is properly flattened *)
       val Program.T {functions, ...} = p'
       val callerFunc' = List.peek (functions, fn f => Func.equals (Function.name f, f_caller))
       val _ = assert (Option.isSome callerFunc', "f_caller should be present")
       val caller_dest = Function.dest (valOf callerFunc')
       val retBlockOpt = List.peek (Vector.toList (#blocks caller_dest), fn b => Label.equals (Block.label b, L_ret))
       val _ = assert (Option.isSome retBlockOpt, "L_ret block should be present")
       val Block.T {args = block_args, statements = stmts, ...} = valOf retBlockOpt
       
       (* Check block arg type is flattened *)
       val _ = assert (Vector.length block_args = 1, "Expected 1 block argument")
       val (v_ret, ty_ret) = Vector.sub (block_args, 0)
       val intArrTy = Type.array intTy
       val expectedTy = Type.tuple (Vector.fromList [intArrTy, intArrTy])
       val _ = assert (Type.equals (ty_ret, expectedTy), "Block arg should be flattened to (int array * int array)")
       
       (* Expectations for properly-flattened IR:
          Array_length should be flattened into 2 statements:
          ret_val_0 = select (ret_val, 0)
          len = Array_length[int] (ret_val_0)
        *)
       val _ = assert (Vector.length stmts = 2, "Expected 2 statements in properly-flattened block")
       val s0 = Vector.sub (stmts, 0)
       val s1 = Vector.sub (stmts, 1)
       
       val Statement.T {exp = exp0, ty = ty0, var = var0} = s0
       val _ = case exp0 of
                   Exp.Select {offset, tuple} =>
                      if offset = 0 andalso Var.equals (tuple, v_ret) then ()
                      else assert (false, "Expected Select offset 0 of ret_val")
                 | _ => assert (false, "Expected Exp.Select")
       val _ = assert (Type.equals (ty0, intArrTy), "Expected selected variable to be int array")
       val v_select = var0
       val _ = assert (Option.isSome v_select, "Expected bound variable on s0")
       val v_select = valOf v_select

       val Statement.T {exp = exp1, ty = ty1, var = var1} = s1
       val _ = case exp1 of
                   Exp.PrimApp {args, prim, targs} =>
                      if Prim.equals (prim, Prim.Array_length)
                         andalso Vector.length args = 1
                         andalso Var.equals (Vector.sub (args, 0), v_select)
                         andalso Vector.length targs = 1
                         andalso Type.equals (Vector.sub (targs, 0), intTy)
                      then ()
                      else assert (false, "Expected Array_length prim app on selected variable")
                  | _ => assert (false, "Expected Exp.PrimApp")
       val _ = assert (Type.equals (ty1, seqIndexTy), "Expected length type to be seqIndexTy")
    in () end)

    (* Test 54: flattenOnce - Array_uninit on tuple array *)
    val _ = runTest ("Test 54: flattenOnce - Array_uninit on tuple array", fn () => let
       val _ = Control.libTargetDir := "../../build/lib/mlton/targets/self"

       val f_main = Func.fromString "f_main"
       val L_start = Label.fromString "L_start"

       val intTy = Type.intInf
       val seqIndexTy = Type.word (Atoms.WordSize.seqIndex ())
       val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
       val arrayTuple2Ty = Type.array tuple2Ty

       val v_alloc = Var.fromString "v_alloc"
       val len = Var.fromString "len"

       val uninitPrim = Prim.Array_uninit
       val s2 = Statement.T {
          exp = Exp.PrimApp {args = Vector.fromList [v_alloc, len],
                             prim = uninitPrim,
                             targs = Vector.new1 tuple2Ty},
          ty = Type.unit,
          var = NONE
       }

       val mainStartBlock = Block.T {
          args = Vector.new0 (),
          label = L_start,
          statements = Vector.fromList [s2],
          transfer = Transfer.Return (Vector.new0 ())
       }

       val mainFunction = Function.new {
          args = Vector.fromList [(v_alloc, arrayTuple2Ty), (len, seqIndexTy)],
          blocks = Vector.fromList [mainStartBlock],
          inline = InlineAttr.Auto,
          name = f_main,
          raises = NONE,
          returns = SOME (Vector.new0 ()),
          start = L_start
       }

       val p = Program.T {
          datatypes = Vector.new0 (),
          functions = [mainFunction],
          globals = Vector.new0 (),
          main = f_main
       }

       val policy = ShallowFlatten.MaxWidth 3
       (* Under the buggy compiler, flattenOnce will raise IllegalFlatteningDecision.
          We want to assert/witness this symptom, but also verify the properly flattened IR.
          So, if IllegalFlatteningDecision is raised, we print a message and raise TestFail.
          If it does not raise, we continue with verifying the properly-flattened IR. *)
       val p' =
          case (SOME (ShallowFlatten.flattenOnce policy p))
               handle ShallowFlatten.IllegalFlatteningDecision => NONE of
             NONE => (assert (true, "Symptom of the original bug present");
                      raise TestFail "Bug is present: flattenOnce raised IllegalFlatteningDecision")
           | SOME (SOME p') => p'
           | SOME NONE => raise TestFail "flattenOnce returned NONE"

       (* Verify the flattened IR of f_main *)
       val Program.T {functions, ...} = p'
       val mainFunc' = List.peek (functions, fn f => Func.equals (Function.name f, f_main))
       val _ = assert (Option.isSome mainFunc', "f_main should be present in the result")
       val f_main_dest = Function.dest (valOf mainFunc')
       val startBlock = Vector.sub (#blocks f_main_dest, 0)
       val Block.T {statements = stmts, ...} = startBlock

       val _ = assert (Vector.length stmts = 4, "Expected 4 statements after flattening Array_uninit")
       
       val s0 = Vector.sub (stmts, 0)
       val s1 = Vector.sub (stmts, 1)
       val s2 = Vector.sub (stmts, 2)
       val s3 = Vector.sub (stmts, 3)

       val intArrTy = Type.array intTy

       (* Verify Statement 0: select 0 of v_alloc *)
       val Statement.T {exp = exp0, ty = ty0, var = var0} = s0
       val _ = case exp0 of
                   Exp.Select {offset, tuple} =>
                      if offset = 0 andalso Var.equals (tuple, v_alloc) then ()
                      else assert (false, "Expected Select offset 0 of v_alloc")
                 | _ => assert (false, "Expected Exp.Select")
       val _ = assert (Type.equals (ty0, intArrTy), "Expected selected variable type to be int array")
       val v_select0 = valOf var0

       (* Verify Statement 1: select 1 of v_alloc *)
       val Statement.T {exp = exp1, ty = ty1, var = var1} = s1
       val _ = case exp1 of
                   Exp.Select {offset, tuple} =>
                      if offset = 1 andalso Var.equals (tuple, v_alloc) then ()
                      else assert (false, "Expected Select offset 1 of v_alloc")
                 | _ => assert (false, "Expected Exp.Select")
       val _ = assert (Type.equals (ty1, intArrTy), "Expected selected variable type to be int array")
       val v_select1 = valOf var1

       (* Verify Statement 2: Array_uninit[intInf](v_select0, len) *)
       val Statement.T {exp = exp2, ty = ty2, var = var2} = s2
       val _ = assert (Type.equals (ty2, Type.unit), "Expected Statement 2 type to be unit")
       val _ = assert (Option.isSome var2, "Expected Statement 2 to have a bound variable")
       val _ = case exp2 of
                   Exp.PrimApp {args, prim, targs} =>
                      if Prim.equals (prim, Prim.Array_uninit)
                         andalso Vector.length args = 2
                         andalso Var.equals (Vector.sub (args, 0), v_select0)
                         andalso Var.equals (Vector.sub (args, 1), len)
                         andalso Vector.length targs = 1
                         andalso Type.equals (Vector.sub (targs, 0), intTy)
                      then ()
                      else assert (false, "Expected Array_uninit[intInf](v_select0, len)")
                 | _ => assert (false, "Expected Exp.PrimApp")

       (* Verify Statement 3: Array_uninit[intInf](v_select1, len) *)
       val Statement.T {exp = exp3, ty = ty3, var = var3} = s3
       val _ = assert (Type.equals (ty3, Type.unit), "Expected Statement 3 type to be unit")
       val _ = assert (Option.isSome var3, "Expected Statement 3 to have a bound variable")
       val _ = case exp3 of
                   Exp.PrimApp {args, prim, targs} =>
                      if Prim.equals (prim, Prim.Array_uninit)
                         andalso Vector.length args = 2
                         andalso Var.equals (Vector.sub (args, 0), v_select1)
                         andalso Var.equals (Vector.sub (args, 1), len)
                         andalso Vector.length targs = 1
                         andalso Type.equals (Vector.sub (targs, 0), intTy)
                      then ()
                      else assert (false, "Expected Array_uninit[intInf](v_select1, len)")
                 | _ => assert (false, "Expected Exp.PrimApp")
    in () end)

    (* Test 55: flattenOnce - NonTail return call to function returning NONE with continuation block arguments *)
    val _ = runTest ("Test 55: flattenOnce - NonTail return call to function returning NONE with continuation block arguments", fn () => let
       val _ = Control.libTargetDir := "../../build/lib/mlton/targets/self"

       val f_main = Func.fromString "f_main"
       val f_noreturn = Func.fromString "f_noreturn"
       val L_start = Label.fromString "L_start"
       val L_cont = Label.fromString "L_cont"
       val L_noreturn = Label.fromString "L_noreturn"

       val intTy = Type.intInf
       val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
       val arrayTuple2Ty = Type.array tuple2Ty
       val v_alloc = Var.fromString "v_alloc"
       val n = Var.fromString "n"
       val v_cont_arg = Var.fromString "v_cont_arg"

       val allocPrim = Prim.Array_alloc {raw = false}
       val s1 = Statement.T {
          exp = Exp.PrimApp {args = Vector.new1 n,
                             prim = allocPrim,
                             targs = Vector.new1 tuple2Ty},
          ty = arrayTuple2Ty,
          var = SOME v_alloc
       }

       val noreturnBlock = Block.T {
          args = Vector.new0 (),
          label = L_noreturn,
          statements = Vector.new0 (),
          transfer = Transfer.Bug
       }

       val noreturnFunction = Function.new {
          args = Vector.new0 (),
          blocks = Vector.fromList [noreturnBlock],
          inline = InlineAttr.Auto,
          name = f_noreturn,
          raises = NONE,
          returns = NONE,
          start = L_noreturn
       }

       val mainStartBlock = Block.T {
          args = Vector.fromList [(n, intTy)],
          label = L_start,
          statements = Vector.fromList [s1],
          transfer = Transfer.Call {
             args = Vector.new0 (),
             func = f_noreturn,
             inline = InlineAttr.Auto,
             return = Return.NonTail {
                cont = L_cont,
                handler = Handler.Caller
             }
          }
       }

       val mainContBlock = Block.T {
          args = Vector.fromList [(v_cont_arg, intTy)],
          label = L_cont,
          statements = Vector.new0 (),
          transfer = Transfer.Return (Vector.new0 ())
        }

        val mainFunction = Function.new {
           args = Vector.new0 (),
           blocks = Vector.fromList [mainStartBlock, mainContBlock],
           inline = InlineAttr.Auto,
           name = f_main,
           raises = NONE,
           returns = SOME (Vector.new0 ()),
           start = L_start
        }

        val p = Program.T {
           datatypes = Vector.new0 (),
           functions = [noreturnFunction, mainFunction],
           globals = Vector.new0 (),
           main = f_main
        }

        val policy = ShallowFlatten.MaxWidth 3
        (* Under the buggy compiler, this will raise Fail msg containing "Vector.foldi2From".
           We want to assert/witness this symptom, but also verify the properly flattened IR. *)
        val p' =
            case (SOME (ShallowFlatten.flattenOnce policy p))
                 handle Fail msg =>
                    if SmlString.hasPrefix (msg, {prefix = "Vector.foldi2From"}) then NONE
                    else raise Fail msg of
             NONE => (assert (true, "Symptom of the original bug present");
                      raise TestFail "Bug is present: flattenOnce raised Vector.foldi2From")
           | SOME (SOME p') => p'
           | SOME NONE => raise TestFail "flattenOnce returned NONE"

        val Program.T {functions, ...} = p'

        (* Verify the flattened IR of f_main *)
        val mainFunc' = List.peek (functions, fn f => Func.equals (Function.name f, f_main))
        val _ = assert (Option.isSome mainFunc', "f_main should be present in the result")
        val f_main_dest = Function.dest (valOf mainFunc')
        val startBlock = Vector.sub (#blocks f_main_dest, 0)
        val Block.T {statements = stmts, transfer = trans, ...} = startBlock

        (* Array_alloc of a 2-tuple should flatten to 3 statements:
           v_alloc_0 = Array_alloc[int](n)
           v_alloc_1 = Array_alloc[int](n)
           v_alloc = tuple(v_alloc_0, v_alloc_1) *)
        val _ = assert (Vector.length stmts = 3, "Expected 3 statements after flattening")

        val s0 = Vector.sub (stmts, 0)
        val s1 = Vector.sub (stmts, 1)
        val s2 = Vector.sub (stmts, 2)

        val intArrTy = Type.array intTy
        val tupleArrTy = Type.tuple (Vector.fromList [intArrTy, intArrTy])

        val Statement.T {ty = ty0, ...} = s0
        val Statement.T {ty = ty1, ...} = s1
        val Statement.T {ty = ty2, ...} = s2

        val _ = assert (Type.equals (ty0, intArrTy), "First flattened statement type should be int array")
        val _ = assert (Type.equals (ty1, intArrTy), "Second flattened statement type should be int array")
        val _ = assert (Type.equals (ty2, tupleArrTy), "Third flattened statement type should be int array * int array")

        (* Verify the transfer of f_main is unchanged *)
        val _ = case trans of
                    Transfer.Call {func, return = Return.NonTail {cont, ...}, ...} =>
                       if Func.equals (func, f_noreturn) andalso Label.equals (cont, L_cont) then ()
                       else assert (false, "Transfer call target or continuation changed")
                  | _ => assert (false, "Expected Transfer.Call transfer")

        (* Verify f_noreturn has returns = NONE *)
        val noreturnFunc' = List.peek (functions, fn f => Func.equals (Function.name f, f_noreturn))
        val _ = assert (Option.isSome noreturnFunc', "f_noreturn should be present in the result")
        val f_noreturn_dest = Function.dest (valOf noreturnFunc')
        val _ = assert (Option.isNone (#returns f_noreturn_dest), "f_noreturn should still have returns = NONE")
     in () end)

   val _ = summarize ()
end
