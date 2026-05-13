local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg

   fun assertType (Statement.T {ty, ...}, expected, msg) =
      if Type.equals (ty, expected) then ()
      else assert (false, msg ^ ": type mismatch")
in
   (* Test 1: Simple program *)
   val _ = runTest ("Test 1: Simple program", fn () => let
      val mainFunc = Func.fromString "main"
      val mainLabel = Label.fromString "L0"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
      }
      val p1 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }

      val _ = ShallowFlatten.transform p1
   in () end)

   (* Test 2: rewriteBfs order and transformation *)
   val _ = runTest ("Test 2: rewriteBfs order and transformation", fn () => let
      val v_g1 = Var.fromString "v_g1"
      val v_g2 = Var.fromString "v_g2"
      val f_main = Func.fromString "f_main"
      val f_dep1 = Func.fromString "f_dep1"
      val f_dep2 = Func.fromString "f_dep2"
      val f_disc = Func.fromString "f_disc"

      val L_start = Label.fromString "L_start"
      val L_1 = Label.fromString "L_1"
      val L_2 = Label.fromString "L_2"
      val L_3 = Label.fromString "L_3"
      val L_disc = Label.fromString "L_disc"

      val ty = Type.intInf

      (* Helper to create a statement *)
      fun stmt (v, e) = Statement.T {exp = e, ty = ty, var = SOME v}

      (* Globals *)
      val g1 = stmt (v_g1, Exp.Const (Const.IntInf 1))
      val g2 = stmt (v_g2, Exp.Var v_g1)

      (* f_dep1: Takes an arg, returns it *)
      val v_arg_dep1 = Var.fromString "v_arg_dep1"
      val v_s_dep1 = Var.fromString "v_s_dep1"
      val L_dep1 = Label.fromString "L_dep1"
      val f_dep1_func = Function.new {
         args = Vector.fromList [(v_arg_dep1, ty)],
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_dep1,
               statements = Vector.fromList [stmt (v_s_dep1, Exp.Var v_arg_dep1)],
               transfer = Transfer.Return (Vector.fromList [v_s_dep1])
            }
         ],
         inline = InlineAttr.Auto,
         name = f_dep1,
         raises = NONE,
         returns = SOME (Vector.fromList [ty]),
         start = L_dep1
      }

      (* f_dep2: Calls f_dep1 *)
      val v_s_dep2 = Var.fromString "v_s_dep2"
      val L_dep2 = Label.fromString "L_dep2"
      val L_dep2_cont = Label.fromString "L_dep2_cont"
      val v_ret_dep1 = Var.fromString "v_ret_dep1"
      val f_dep2_func = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_dep2,
               statements = Vector.fromList [stmt (v_s_dep2, Exp.Var v_g2)],
               transfer = Transfer.Call {
                  args = Vector.fromList [v_s_dep2],
                  func = f_dep1,
                  inline = InlineAttr.Auto,
                  return = Return.NonTail {
                     cont = L_dep2_cont,
                     handler = Handler.Caller
                  }
               }
            },
            Block.T {
               args = Vector.fromList [(v_ret_dep1, ty)],
               label = L_dep2_cont,
               statements = Vector.new0 (),
               transfer = Transfer.Return (Vector.fromList [v_ret_dep1])
            }
         ],
         inline = InlineAttr.Auto,
         name = f_dep2,
         raises = NONE,
         returns = SOME (Vector.fromList [ty]),
         start = L_dep2
      }

      (* f_main: Calls f_dep2, has complex CFG *)
      val f_main_func = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_start,
               statements = Vector.fromList [stmt (Var.fromString "v_s_start", Exp.Const (Const.IntInf 10))],
               transfer = Transfer.Goto {args = Vector.new0 (), dst = L_1}
            },
            Block.T {
               args = Vector.new0 (),
               label = L_1,
               statements = Vector.fromList [stmt (Var.fromString "v_s_L1", Exp.Const (Const.IntInf 11))],
               transfer = Transfer.Case {
                  cases = Cases.Con (Vector.new0 ()),
                  default = SOME L_2,
                  test = v_g1
               }
            },
            Block.T {
               args = Vector.new0 (),
               label = L_2,
               statements = Vector.fromList [stmt (Var.fromString "v_s_L2", Exp.Const (Const.IntInf 12))],
               transfer = Transfer.Goto {args = Vector.new0 (), dst = L_3}
            },
            Block.T {
               args = Vector.new0 (),
               label = L_3,
               statements = Vector.fromList [stmt (Var.fromString "v_s_L3", Exp.Const (Const.IntInf 13))],
               transfer = Transfer.Return (Vector.new0 ())
            },
            Block.T {
               args = Vector.new0 (),
               label = L_disc,
               statements = Vector.fromList [stmt (Var.fromString "v_s_Ldisc", Exp.Const (Const.IntInf 14))],
               transfer = Transfer.Bug
            }
         ],
         inline = InlineAttr.Auto,
         name = f_main,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = L_start
      }

      (* f_disc: Disconnected function *)
      val L_disc_f = Label.fromString "L_disc_f"
      val v_s_disc_f = Var.fromString "v_s_disc_f"
      val f_disc_func = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_disc_f,
               statements = Vector.fromList [stmt (v_s_disc_f, Exp.Const (Const.IntInf 15))],
               transfer = Transfer.Return (Vector.new0 ())
            }
         ],
         inline = InlineAttr.Auto,
         name = f_disc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = L_disc_f
      }

      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [f_dep1_func, f_dep2_func, f_main_func, f_disc_func],
         globals = Vector.fromList [g1, g2],
         main = f_main
      }

      val visited = ref []
      fun log s = (
         (* print ("LOG: " ^ s ^ "\n"); *)
         visited := s :: (!visited)
      )

      val rewriter: ShallowFlatten.rewriter = {
         doStatements = fn stmts => (
            Vector.foreach (stmts, fn Statement.T {var, ...} =>
               case var of
                  SOME v => log ("Stmt: " ^ Var.toString v)
                | NONE => log "Stmt: <no var>");
            stmts
         ),
         doArgs = fn args => (
            Vector.foreach (args, fn (v, t) => log ("Arg: " ^ Var.toString v));
            args
         ),
         doTransfer = fn t => (
            log ("Transfer: " ^ (Layout.toString (Transfer.layout t)));
            t
         )
      }

      val _ = ShallowFlatten.rewriteBfs rewriter p
      val visitOrder = List.rev (!visited)

      (* Check BFS guarantees *)
      fun indexOf s =
         let
            fun loop (i, []) = NONE
              | loop (i, x::xs) = if String.hasSubstring (x, {substring = s}) then SOME i else loop (i + 1, xs)
         in loop (0, visitOrder) end

      fun checkBefore (a, b, msg) =
         case (indexOf a, indexOf b) of
            (SOME i, SOME j) => if i < j then () else assert (false, msg ^ " (" ^ a ^ " should be before " ^ b ^ ")")
          | (NONE, _) => assert (false, "Missing " ^ a)
          | (_, NONE) => assert (false, "Missing " ^ b)

      (* 1. Globals before functions *)
      val _ = checkBefore ("Stmt: v_g1", "Arg: v_arg_dep1", "Global v_g1 before f_dep1 arg")
      val _ = checkBefore ("Stmt: v_g2", "Arg: v_arg_dep1", "Global v_g2 before f_dep1 arg")
      
      (* 2. Functions in topological order: f_dep1 -> f_dep2 *)
      val _ = checkBefore ("Stmt: v_s_dep1", "Stmt: v_s_dep2", "f_dep1 body before f_dep2 body")

      (* 3. Function args before blocks *)
      val _ = checkBefore ("Arg: v_arg_dep1", "Stmt: v_s_dep1", "f_dep1 arg before its body")

      (* 4. Blocks in topological order within f_main: L_start -> L_1 -> L_2 -> L_3 *)
      val _ = checkBefore ("Stmt: v_s_start", "Stmt: v_s_L1", "L_start before L_1")
      val _ = checkBefore ("Stmt: v_s_L1", "Stmt: v_s_L2", "L_1 before L_2")
      val _ = checkBefore ("Stmt: v_s_L2", "Stmt: v_s_L3", "L_2 before L_3")

      (* 5. Block args before block body *)
      val _ = checkBefore ("Arg: v_ret_dep1", "return (v_ret_dep1)", "L_dep2_cont arg before its transfer")

      (* 6. Disconnected components visited *)
      val _ = assert (Option.isSome (indexOf "Stmt: v_s_Ldisc"), "Disconnected block L_disc visited")
      val _ = assert (Option.isSome (indexOf "Stmt: v_s_disc_f"), "Disconnected function f_disc visited")
   in () end)

   (* Test 3: foreachBfs order *)
   val _ = runTest ("Test 3: foreachBfs order", fn () => let
      val v_g1 = Var.fromString "v_g1"
      val v_g2 = Var.fromString "v_g2"
      val f_main = Func.fromString "f_main"
      val f_dep1 = Func.fromString "f_dep1"
      val f_dep2 = Func.fromString "f_dep2"
      val f_disc = Func.fromString "f_disc"

      val L_start = Label.fromString "L_start"
      val L_1 = Label.fromString "L_1"
      val L_2 = Label.fromString "L_2"
      val L_3 = Label.fromString "L_3"
      val L_disc = Label.fromString "L_disc"

      val ty = Type.intInf

      (* Helper to create a statement *)
      fun stmt (v, e) = Statement.T {exp = e, ty = ty, var = SOME v}

      (* Globals *)
      val g1 = stmt (v_g1, Exp.Const (Const.IntInf 1))
      val g2 = stmt (v_g2, Exp.Var v_g1)

      (* f_dep1: Takes an arg, returns it *)
      val v_arg_dep1 = Var.fromString "v_arg_dep1"
      val v_s_dep1 = Var.fromString "v_s_dep1"
      val L_dep1 = Label.fromString "L_dep1"
      val f_dep1_func = Function.new {
         args = Vector.fromList [(v_arg_dep1, ty)],
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_dep1,
               statements = Vector.fromList [stmt (v_s_dep1, Exp.Var v_arg_dep1)],
               transfer = Transfer.Return (Vector.fromList [v_s_dep1])
            }
         ],
         inline = InlineAttr.Auto,
         name = f_dep1,
         raises = NONE,
         returns = SOME (Vector.fromList [ty]),
         start = L_dep1
      }

      (* f_dep2: Calls f_dep1 *)
      val v_s_dep2 = Var.fromString "v_s_dep2"
      val L_dep2 = Label.fromString "L_dep2"
      val L_dep2_cont = Label.fromString "L_dep2_cont"
      val v_ret_dep1 = Var.fromString "v_ret_dep1"
      val f_dep2_func = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_dep2,
               statements = Vector.fromList [stmt (v_s_dep2, Exp.Var v_g2)],
               transfer = Transfer.Call {
                  args = Vector.fromList [v_s_dep2],
                  func = f_dep1,
                  inline = InlineAttr.Auto,
                  return = Return.NonTail {
                     cont = L_dep2_cont,
                     handler = Handler.Caller
                  }
               }
            },
            Block.T {
               args = Vector.fromList [(v_ret_dep1, ty)],
               label = L_dep2_cont,
               statements = Vector.new0 (),
               transfer = Transfer.Return (Vector.fromList [v_ret_dep1])
            }
         ],
         inline = InlineAttr.Auto,
         name = f_dep2,
         raises = NONE,
         returns = SOME (Vector.fromList [ty]),
         start = L_dep2
      }

      (* f_main: Calls f_dep2, has complex CFG *)
      val f_main_func = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_start,
               statements = Vector.fromList [stmt (Var.fromString "v_s_start", Exp.Const (Const.IntInf 10))],
               transfer = Transfer.Goto {args = Vector.new0 (), dst = L_1}
            },
            Block.T {
               args = Vector.new0 (),
               label = L_1,
               statements = Vector.fromList [stmt (Var.fromString "v_s_L1", Exp.Const (Const.IntInf 11))],
               transfer = Transfer.Case {
                  cases = Cases.Con (Vector.new0 ()),
                  default = SOME L_2,
                  test = v_g1
               }
            },
            Block.T {
               args = Vector.new0 (),
               label = L_2,
               statements = Vector.fromList [stmt (Var.fromString "v_s_L2", Exp.Const (Const.IntInf 12))],
               transfer = Transfer.Goto {args = Vector.new0 (), dst = L_3}
            },
            Block.T {
               args = Vector.new0 (),
               label = L_3,
               statements = Vector.fromList [stmt (Var.fromString "v_s_L3", Exp.Const (Const.IntInf 13))],
               transfer = Transfer.Return (Vector.new0 ())
            },
            Block.T {
               args = Vector.new0 (),
               label = L_disc,
               statements = Vector.fromList [stmt (Var.fromString "v_s_Ldisc", Exp.Const (Const.IntInf 14))],
               transfer = Transfer.Bug
            }
         ],
         inline = InlineAttr.Auto,
         name = f_main,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = L_start
      }

      (* f_disc: Disconnected function *)
      val L_disc_f = Label.fromString "L_disc_f"
      val v_s_disc_f = Var.fromString "v_s_disc_f"
      val f_disc_func = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [
            Block.T {
               args = Vector.new0 (),
               label = L_disc_f,
               statements = Vector.fromList [stmt (v_s_disc_f, Exp.Const (Const.IntInf 15))],
               transfer = Transfer.Return (Vector.new0 ())
            }
         ],
         inline = InlineAttr.Auto,
         name = f_disc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = L_disc_f
      }

      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [f_dep1_func, f_dep2_func, f_main_func, f_disc_func],
         globals = Vector.fromList [g1, g2],
         main = f_main
      }

      val visited = ref []
      fun log s = (
         (* print ("LOG: " ^ s ^ "\n"); *)
         visited := s :: (!visited)
      )

      val visitor: ShallowFlatten.visitor = {
         foreachStatements = fn stmts =>
            Vector.foreach (stmts, fn Statement.T {var, ...} =>
               case var of
                  SOME v => log ("Stmt: " ^ Var.toString v)
                | NONE => log "Stmt: <no var>"),
         foreachArgs = fn args =>
            Vector.foreach (args, fn (v, t) => log ("Arg: " ^ Var.toString v)),
         foreachTransfer = fn t =>
            log ("Transfer: " ^ (Layout.toString (Transfer.layout t)))
      }

      val _ = ShallowFlatten.foreachBfs visitor p
      val visitOrder = List.rev (!visited)

      (* Check BFS guarantees *)
      fun indexOf s =
         let
            fun loop (i, []) = NONE
              | loop (i, x::xs) = if String.hasSubstring (x, {substring = s}) then SOME i else loop (i + 1, xs)
         in loop (0, visitOrder) end

      fun checkBefore (a, b, msg) =
         case (indexOf a, indexOf b) of
            (SOME i, SOME j) => if i < j then () else assert (false, msg ^ " (" ^ a ^ " should be before " ^ b ^ ")")
          | (NONE, _) => assert (false, "Missing " ^ a)
          | (_, NONE) => assert (false, "Missing " ^ b)

      (* 1. Globals before functions *)
      val _ = checkBefore ("Stmt: v_g1", "Arg: v_arg_dep1", "Global v_g1 before f_dep1 arg")
      val _ = checkBefore ("Stmt: v_g2", "Arg: v_arg_dep1", "Global v_g2 before f_dep1 arg")
      
      (* 2. Functions in topological order: f_dep1 -> f_dep2 *)
      val _ = checkBefore ("Stmt: v_s_dep1", "Stmt: v_s_dep2", "f_dep1 body before f_dep2 body")

      (* 3. Function args before blocks *)
      val _ = checkBefore ("Arg: v_arg_dep1", "Stmt: v_s_dep1", "f_dep1 arg before its body")

      (* 4. Blocks in topological order within f_main: L_start -> L_1 -> L_2 -> L_3 *)
      val _ = checkBefore ("Stmt: v_s_start", "Stmt: v_s_L1", "L_start before L_1")
      val _ = checkBefore ("Stmt: v_s_L1", "Stmt: v_s_L2", "L_1 before L_2")
      val _ = checkBefore ("Stmt: v_s_L2", "Stmt: v_s_L3", "L_2 before L_3")

      (* 5. Block args before block body *)
      val _ = checkBefore ("Arg: v_ret_dep1", "return (v_ret_dep1)", "L_dep2_cont arg before its transfer")

      (* 6. Disconnected components visited *)
      val _ = assert (Option.isSome (indexOf "Stmt: v_s_Ldisc"), "Disconnected block L_disc visited")
      val _ = assert (Option.isSome (indexOf "Stmt: v_s_disc_f"), "Disconnected function f_disc visited")
   in () end)

   (* Test 4: maybeFlattenType *)
   val _ = runTest ("Test 4: maybeFlattenType", fn () => let
      fun check (input, expected, msg) =
         let
            val res = ShallowFlatten.maybeFlattenType input
         in
            case (res, expected) of
               (NONE, NONE) => ()
             | (SOME r, SOME e) => 
               if Type.equals (r, e) then ()
               else assert (false, msg ^ ": type mismatch")
             | (SOME _, NONE) => assert (false, msg ^ ": expected NONE, got SOME")
             | (NONE, SOME _) => assert (false, msg ^ ": expected SOME, got NONE")
         end

      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val expected2 = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])

      val tuple3Ty = Type.tuple (Vector.fromList [intTy, intTy, intTy])
      val arrayTuple3Ty = Type.array tuple3Ty
      val expected3 = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy, Type.array intTy])

      val nestedTupleTy = Type.tuple (Vector.fromList [intTy, tuple2Ty])
      val arrayNestedTupleTy = Type.array nestedTupleTy
      val expectedNested = Type.tuple (Vector.fromList [Type.array intTy, Type.array tuple2Ty])
   in
      check (arrayTuple2Ty, SOME expected2, "simple 2-tuple array");
      check (arrayTuple3Ty, SOME expected3, "simple 3-tuple array");
      check (arrayNestedTupleTy, SOME expectedNested, "nested tuple array");
      check (intTy, NONE, "not an array");
      check (Type.array intTy, NONE, "array of non-tuple");
      check (tuple2Ty, NONE, "tuple but not array")
   end)

   (* Test 5: flattenedVars *)
   val _ = runTest ("Test 5: flattenedVars", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v1)), "v1 should not be marked initially")
      val _ = ShallowFlatten.markForFlatten (fv, v1)
      val _ = assert (ShallowFlatten.isMarkedForFlatten (fv, v1), "v1 should be marked after markForFlatten")
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v2)), "v2 should not be marked")
   in () end)

   (* Test 6: markedCount *)
   val _ = runTest ("Test 6: markedCount", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val v3 = Var.fromString "v3"

      val _ = assert (ShallowFlatten.markedCount fv = 0, "Initial count should be 0")
      
      val _ = ShallowFlatten.markForFlatten (fv, v1)
      val _ = assert (ShallowFlatten.markedCount fv = 1, "Count should be 1 after marking v1")
      
      val _ = ShallowFlatten.markForFlatten (fv, v2)
      val _ = assert (ShallowFlatten.markedCount fv = 2, "Count should be 2 after marking v2")

      (* Re-marking the same variable is illegal *)
      
      val _ = ShallowFlatten.markForFlatten (fv, v3)
      val _ = assert (ShallowFlatten.markedCount fv = 3, "Count should be 3 after marking v3")
   in () end)

   (* Test 7: maybeFlattenArg *)
   val _ = runTest ("Test 7: maybeFlattenArg", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val v3 = Var.fromString "v3"
      
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val expected2 = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])

      (* Case 1: Not marked for flattening *)
      val (rv1, rt1) = ShallowFlatten.maybeFlattenArg (fv, (v1, arrayTuple2Ty))
      val _ = assert (Var.equals (rv1, v1), "Case 1: var mismatch")
      val _ = assert (Type.equals (rt1, arrayTuple2Ty), "Case 1: type mismatch")

      (* Case 2: Marked for flattening, valid type *)
      val _ = ShallowFlatten.markForFlatten (fv, v2)
      val (rv2, rt2) = ShallowFlatten.maybeFlattenArg (fv, (v2, arrayTuple2Ty))
      val _ = assert (Var.equals (rv2, v2), "Case 2: var mismatch")
      val _ = assert (Type.equals (rt2, expected2), "Case 2: type mismatch")

      (* Case 3: Marked for flattening, invalid type *)
      val _ = ShallowFlatten.markForFlatten (fv, v3)
      val _ = (ShallowFlatten.maybeFlattenArg (fv, (v3, intTy)); 
               assert (false, "Case 3: should have raised BadFlattenError"))
              handle ShallowFlatten.BadFlattenError => ()
                   | _ => assert (false, "Case 3: raised wrong exception")
   in () end)

   (* Test 8: maybeFlattenStatement *)
   val _ = runTest ("Test 8: maybeFlattenStatement (Array_length)", fn () => let
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

      (* Case 1: Non-flattenable statement (Const) *)
      val s1 = Statement.T {exp = Exp.Const (Const.IntInf 1), ty = intTy, var = SOME v1}
      val _ = assert (Option.isNone (ShallowFlatten.maybeFlattenStatement s1), "s1 should not be flattenable")

      (* Case 2: Array_alloc on non-tuple type *)
      val s2 = Statement.T {
         exp = primApp (allocPrim, [n], [intTy]),
         ty = Type.array intTy,
         var = SOME v1
      }
      val _ = assert (Option.isNone (ShallowFlatten.maybeFlattenStatement s2), "s2 should not be flattenable")

      (* Case 4: Array_length on tuple type *)
      val lengthPrim = Prim.Array_length
      val arr = Var.fromString "arr"
      val s4 = Statement.T {
         exp = primApp (lengthPrim, [arr], [tuple2Ty]),
         ty = intTy,
         var = SOME v1
      }
      val res4 = ShallowFlatten.maybeFlattenStatement s4
      val stmts4 = case res4 of
                      SOME s => s
                    | NONE => raise TestFail "s4 should be flattenable"
      val _ = assert (Vector.length stmts4 = 2, "s4 should flatten to 2 statements")
      val _ = assertType (Vector.sub (stmts4, 0), Type.array intTy, "s4 stmt 0 type")
      val _ = assertType (Vector.sub (stmts4, 1), intTy, "s4 stmt 1 type")
   in () end)

   (* Test 9: maybeFlattenStatement (Array_alloc) *)
   val _ = runTest ("Test 9: maybeFlattenStatement (Array_alloc)", fn () => let
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

      (* Case 3: Array_alloc on tuple type *)
      val s3 = Statement.T {
         exp = primApp (allocPrim, [n], [tuple2Ty]),
         ty = arrayTuple2Ty,
         var = SOME v1
      }
      val res3 = ShallowFlatten.maybeFlattenStatement s3
      val stmts = case res3 of
                     SOME s => s
                   | NONE => raise TestFail "s3 should be flattenable"
      val _ = assert (Vector.length stmts = 3,
                      concat ["s3 should flatten to 3 statements, got ",
                              Int.toString (Vector.length stmts)])
      val _ = assertType (Vector.sub (stmts, 0), Type.array intTy, "s3 stmt 0 type")
      val _ = assertType (Vector.sub (stmts, 1), Type.array intTy, "s3 stmt 1 type")
      val _ = assertType (Vector.sub (stmts, 2), 
                          Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy]), 
                          "s3 stmt 2 type")
   in () end)

   (* Test 10: maybeFlattenStatement (Array_sub) *)
   val _ = runTest ("Test 10: maybeFlattenStatement (Array_sub)", fn () => let
      val v1 = Var.fromString "v1"
      val arr = Var.fromString "arr"
      val i = Var.fromString "i"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])

      fun primApp (p, args, targs) = 
         Exp.PrimApp {args = Vector.fromList args,
                      prim = p,
                      targs = Vector.fromList targs}

      val subPrim = Prim.Array_sub {readBarrier = false}
      val s = Statement.T {
         exp = primApp (subPrim, [arr, i], [tuple2Ty]),
         ty = tuple2Ty,
         var = SOME v1
      }
      val res = ShallowFlatten.maybeFlattenStatement s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_sub should be flattenable"
      
      (* Expected:
         1. arr_a = select(arr, 0)
         2. x_a = Array_sub(arr_a, i)
         3. arr_b = select(arr, 1)
         4. x_b = Array_sub(arr_b, i)
         5. v1 = tuple(x_a, x_b)
      *)
      val _ = assert (Vector.length stmts = 5, "Array_sub should flatten to 5 statements")
      val _ = assertType (Vector.sub (stmts, 0), Type.array intTy, "Array_sub stmt 0 type")
      val _ = assertType (Vector.sub (stmts, 1), Type.array intTy, "Array_sub stmt 1 type")
      val _ = assertType (Vector.sub (stmts, 2), intTy, "Array_sub stmt 2 type")
      val _ = assertType (Vector.sub (stmts, 3), intTy, "Array_sub stmt 3 type")
      val _ = assertType (Vector.sub (stmts, 4), tuple2Ty, "Array_sub stmt 4 type")
      val _ = Vector.foreach (stmts, fn Statement.T {exp, ty, var} =>
         case exp of
            Exp.Select {offset, tuple} => assert (Var.equals (tuple, arr), "Select should be from arr")
          | Exp.PrimApp {prim, ...} => 
            (case prim of
                Prim.Array_sub _ => ()
              | _ => assert (false, "Expected Array_sub or Select or Tuple"))
          | Exp.Tuple _ => ()
          | _ => assert (false, "Unexpected expression in flattened Array_sub"))
   in () end)

   (* Test 11: maybeFlattenStatement (Array_update) *)
   val _ = runTest ("Test 11: maybeFlattenStatement (Array_update)", fn () => let
      val arr = Var.fromString "arr"
      val i = Var.fromString "i"
      val x = Var.fromString "x"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])

      fun assertType (Statement.T {ty, ...}, expected, msg) =
         if Type.equals (ty, expected) then ()
         else assert (false, msg ^ ": type mismatch (got " ^ (Layout.toString (Type.layout ty)) ^ ")")

      fun primApp (p, args, targs) = 
         Exp.PrimApp {args = Vector.fromList args,
                      prim = p,
                      targs = Vector.fromList targs}

      val updatePrim = Prim.Array_update {writeBarrier = false}
      val s = Statement.T {
         exp = primApp (updatePrim, [arr, i, x], [tuple2Ty]),
         ty = Type.unit,
         var = NONE
      }
      val res = ShallowFlatten.maybeFlattenStatement s
      val stmts = case res of
                     SOME s => s
                   | NONE => raise TestFail "Array_update should be flattenable"
      
      (* Expected:
         1. arr_a = select(arr, 0)
         2. x_a = select(x, 0)
         3. _ = Array_update(arr_a, i, x_a)
         4. arr_b = select(arr, 1)
         5. x_b = select(x, 1)
         6. _ = Array_update(arr_b, i, x_b)
      *)
      val _ = assert (Vector.length stmts = 6, "Array_update should flatten to 6 statements")
      val _ = assertType (Vector.sub (stmts, 0), Type.array intTy, "Array_update stmt 0 type")
      val _ = assertType (Vector.sub (stmts, 1), Type.array intTy, "Array_update stmt 1 type")
      val _ = assertType (Vector.sub (stmts, 2), intTy, "Array_update stmt 2 type")
      val _ = assertType (Vector.sub (stmts, 3), intTy, "Array_update stmt 3 type")
      val _ = assertType (Vector.sub (stmts, 4), Type.unit, "Array_update stmt 4 type")
      val _ = assertType (Vector.sub (stmts, 5), Type.unit, "Array_update stmt 5 type")
      val _ = Vector.foreach (stmts, fn Statement.T {exp, ty, var} =>
         case exp of
            Exp.Select {offset, tuple} => 
            assert (Var.equals (tuple, arr) orelse Var.equals (tuple, x), "Select should be from arr or x")
          | Exp.PrimApp {prim, ...} => 
            (case prim of
                Prim.Array_update _ => ()
              | _ => assert (false, "Expected Array_update or Select"))
          | _ => assert (false, "Unexpected expression in flattened Array_update"))
   in () end)

   (* Test 12: mustFlattenStatement *)
   val _ = runTest ("Test 12: mustFlattenStatement", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
      val v1 = Var.fromString "v1"
      val v2 = Var.fromString "v2"
      val v3 = Var.fromString "v3"
      val intTy = Type.intInf
      
      (* Case 1: Defines marked variable *)
      val _ = ShallowFlatten.markForFlatten (fv, v1)
      val s1 = Statement.T {exp = Exp.Const (Const.IntInf 1), ty = intTy, var = SOME v1}
      val _ = assert (ShallowFlatten.mustFlattenStatement (fv, s1), "Case 1: should be true (defines v1)")
      
      (* Case 2: Uses marked variable *)
      val s2 = Statement.T {exp = Exp.Var v1, ty = intTy, var = SOME v2}
      val _ = assert (ShallowFlatten.mustFlattenStatement (fv, s2), "Case 2: should be true (uses v1)")
      
      (* Case 3: Neither defines nor uses marked variable *)
      val s3 = Statement.T {exp = Exp.Var v2, ty = intTy, var = SOME v3}
      val _ = assert (not (ShallowFlatten.mustFlattenStatement (fv, s3)), "Case 3: should be false")
      
      (* Case 4: Statement with NONE var, but uses marked variable *)
      val s4 = Statement.T {exp = Exp.Var v1, ty = intTy, var = NONE}
      val _ = assert (ShallowFlatten.mustFlattenStatement (fv, s4), "Case 4: should be true (uses v1, var=NONE)")

      (* Case 5: Complex expression using marked variable *)
      val s5 = Statement.T {
         exp = Exp.Tuple (Vector.fromList [v2, v1]),
         ty = Type.tuple (Vector.fromList [intTy, intTy]),
         var = SOME v3
      }
      val _ = assert (ShallowFlatten.mustFlattenStatement (fv, s5), "Case 5: should be true (uses v1 in tuple)")
   in () end)

   (* Test 13: markStatementForPolicy *)
   val _ = runTest ("Test 13: markStatementForPolicy", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
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

      (* Policy: Flatten if tuple width <= 2 *)
      val policy = ShallowFlatten.MaxWidth 2

      (* Case 1: Array of 2-tuple. Should be marked. *)
      val s1 = Statement.T {
         exp = primApp (allocPrim, [n], [tuple2Ty]),
         ty = arrayTuple2Ty,
         var = SOME v1
      }
      val _ = ShallowFlatten.markStatementForPolicy (fv, policy) s1
      val _ = assert (ShallowFlatten.isMarkedForFlatten (fv, v1), "Case 1: v1 should be marked")

      (* Case 2: Array of 4-tuple. Should NOT be marked (MaxWidth 3). *)
      val v2 = Var.fromString "v2"
      val tuple4Ty = Type.tuple (Vector.tabulate (4, fn _ => intTy))
      val s2 = Statement.T {
         exp = primApp (allocPrim, [n], [tuple4Ty]),
         ty = Type.array tuple4Ty,
         var = SOME v2
      }
      val _ = ShallowFlatten.markStatementForPolicy (fv, policy) s2
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v2)), "Case 2: v2 should NOT be marked")

      (* Case 4: Array of 3-tuple. Should NOT be marked (MaxWidth 2, 3 <= 2 is false). *)
      val v4 = Var.fromString "v4"
      val tuple3Ty = Type.tuple (Vector.tabulate (3, fn _ => intTy))
      val s4 = Statement.T {
         exp = primApp (allocPrim, [n], [tuple3Ty]),
         ty = Type.array tuple3Ty,
         var = SOME v4
      }
      val _ = ShallowFlatten.markStatementForPolicy (fv, policy) s4
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v4)), "Case 4: v4 should NOT be marked")

      (* Case 3: Non-array binding. Should NOT be marked. *)
      val v3 = Var.fromString "v3"
      val s3 = Statement.T {
         exp = Exp.Const (Const.IntInf 1),
         ty = intTy,
         var = SOME v3
      }
      val _ = ShallowFlatten.markStatementForPolicy (fv, policy) s3
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v3)), "Case 3: v3 should NOT be marked")
   in () end)

   (* Test 14: markArgForPolicy *)
   val _ = runTest ("Test 14: markArgForPolicy", fn () => let
      val fv = ShallowFlatten.newFlattenedVars ()
      val intTy = Type.intInf
      val policy = ShallowFlatten.MaxWidth 2

      (* Case 1: Array of 2-tuple argument. Should be marked. *)
      val v1 = Var.fromString "v1"
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val arg1 = (v1, arrayTuple2Ty)
      val _ = ShallowFlatten.markArgForPolicy (fv, policy) arg1
      val _ = assert (ShallowFlatten.isMarkedForFlatten (fv, v1), "Case 1: v1 (arg) should be marked")

      (* Case 2: Array of 4-tuple argument. Should NOT be marked (MaxWidth 2). *)
      val v2 = Var.fromString "v2"
      val tuple4Ty = Type.tuple (Vector.tabulate (4, fn _ => intTy))
      val arrayTuple4Ty = Type.array tuple4Ty
      val arg2 = (v2, arrayTuple4Ty)
      val _ = ShallowFlatten.markArgForPolicy (fv, policy) arg2
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v2)), "Case 2: v2 (arg) should NOT be marked")

      (* Case 3: Non-array argument. Should NOT be marked. *)
      val v3 = Var.fromString "v3"
      val arg3 = (v3, intTy)
      val _ = ShallowFlatten.markArgForPolicy (fv, policy) arg3
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v3)), "Case 3: v3 (arg) should NOT be marked")

      (* Case 4: Array of 3-tuple argument. Should NOT be marked (MaxWidth 2). *)
      val v4 = Var.fromString "v4"
      val tuple3Ty = Type.tuple (Vector.tabulate (3, fn _ => intTy))
      val arrayTuple3Ty = Type.array tuple3Ty
      val arg4 = (v4, arrayTuple3Ty)
      val _ = ShallowFlatten.markArgForPolicy (fv, policy) arg4
      val _ = assert (not (ShallowFlatten.isMarkedForFlatten (fv, v4)), "Case 4: v4 (arg) should NOT be marked")
   in () end)

   (* Test 15: flattenOnce (no flattening needed) *)
   val _ = runTest ("Test 15: flattenOnce (no flattening needed)", fn () => let
      val mainFunc = Func.fromString "main"
      val mainLabel = Label.fromString "L0"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
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
      assert (Option.isNone res, "Should return NONE when no flattening is possible")
   end)

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
   end)

   (* Test 17: shallowFlattenMaxIters *)
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
   end)

   (* Test 18: shallowFlattenPolicy *)
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
   end)

   (* Test 19: maybeFlattenStatement (Array_toVector) *)
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
   in () end)

   (* Test 20: maybeFlattenStatement (Array_alloc {raw = false}) *)
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
   in () end)

   (* Test 21: maybeFlattenStatement (Array_sub {readBarrier = true}) *)
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
   in () end)

   (* Test 22: maybeFlattenStatement (Array_update {writeBarrier = true}) *)
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
   in () end)

   (* Test 23: maybeFlattenStatement (Vector_length) *)
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
   in () end)

   (* Test 24: maybeFlattenStatement (Vector_sub) *)
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
   in () end)

   (* Test 25: Array_toVector followed by Tuple constructor *)
   val _ = runTestDisabled ("Test 25: Array_toVector followed by Tuple constructor", fn () => let
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

   (* Test 26: Nested Tuple constructors *)
   val _ = runTestDisabled ("Test 26: Nested Tuple constructors", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val n = Var.fromString "n"
      val other = Var.fromString "other"
      val x = Var.fromString "x"
      val y = Var.fromString "y"
      val z = Var.fromString "z"
      
      val intTy = Type.intInf
      val word32Ty = Type.word WordSize.word32
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty

      val s1 = Statement.T {
         exp = Exp.PrimApp {args = Vector.new1 n,
                            prim = Prim.Array_alloc {raw = false},
                            targs = Vector.new1 tuple2Ty},
         ty = arrayTuple2Ty,
         var = SOME x
      }
      
      val s2 = Statement.T {
         exp = Exp.Tuple (Vector.fromList [x, other]),
         ty = Type.tuple (Vector.fromList [arrayTuple2Ty, word32Ty]),
         var = SOME y
      }

      val s3 = Statement.T {
         exp = Exp.Tuple (Vector.fromList [y, other]),
         ty = Type.tuple (Vector.fromList [Type.tuple (Vector.fromList [arrayTuple2Ty, word32Ty]), word32Ty]),
         var = SOME z
      }

      val mainBlock = Block.T {
         args = Vector.fromList [(n, intTy), (other, word32Ty)],
         label = L0,
         statements = Vector.fromList [s1, s2, s3],
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
      
      (* Check the type of z in the rewritten stmts *)
      val z_stmt = Vector.last stmts'
      val Statement.T {ty = z_ty, ...} = z_stmt
      
      val flattenedXty = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])
      val expectedYty = Type.tuple (Vector.fromList [flattenedXty, word32Ty])
      val expectedZty = Type.tuple (Vector.fromList [expectedYty, word32Ty])
      
      val _ = if Type.equals (z_ty, expectedZty) then ()
              else assert (false, "z type mismatch: " ^ (Layout.toString (Type.layout z_ty)) ^ 
                                 " expected " ^ (Layout.toString (Type.layout expectedZty)))
   in () end)

   (* Test 27: non-PrimApp flattening (array) *)
   val _ = runTest ("Test 27: non-PrimApp flattening (array)", fn () => let
      val v1 = Var.newString "v1"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = arrayTuple2Ty,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
      val _ = case res of
                  SOME _ => ()
                | NONE => raise TestFail "Should flatten non-PrimApp array with flattenable type"
      val ss = valOf res
      val _ = assert (Vector.length ss = 1, "Should result in exactly one statement")
      val Statement.T {ty = resTy, ...} = Vector.sub (ss, 0)
      val expectedTy = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])
   in
      assert (Type.equals (resTy, expectedTy), "Resulting type should be flattened")
   end)

   (* Test 28: non-PrimApp flattening (vector) *)
   val _ = runTest ("Test 28: non-PrimApp flattening (vector)", fn () => let
      val v1 = Var.newString "v1"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val vectorTuple2Ty = Type.vector tuple2Ty
      
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = vectorTuple2Ty,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
      val _ = case res of
                  SOME _ => ()
                | NONE => raise TestFail "Should flatten non-PrimApp vector with flattenable type"
      val ss = valOf res
      val _ = assert (Vector.length ss = 1, "Should result in exactly one statement")
      val Statement.T {ty = resTy, ...} = Vector.sub (ss, 0)
      val expectedTyVec = Type.tuple (Vector.fromList [Type.vector intTy, Type.vector intTy])
   in
      assert (Type.equals (resTy, expectedTyVec), "Resulting type should be flattened to vectors")
   end)

   (* Test 29: non-PrimApp no-flattening (not a tuple) *)
   val _ = runTest ("Test 29: non-PrimApp no-flattening (not a tuple)", fn () => let
      val v1 = Var.newString "v1"
      val intTy = Type.intInf
      val arrayIntTy = Type.array intTy
      
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = arrayIntTy,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
   in
      case res of
          SOME _ => raise TestFail "Should NOT flatten non-PrimApp with non-flattenable type"
        | NONE => ()
   end)

   (* Test 30: varTypes *)
   val _ = runTest ("Test 30: varTypes", fn () => let
      val vt = ShallowFlatten.newVarTypes ()
      val v1 = Var.newString "v1"
      val intTy = Type.intInf
      val word32Ty = Type.word WordSize.word32
      
      (* First set *)
      val _ = ShallowFlatten.setVarType (vt, v1, intTy)
      val resTy1 = ShallowFlatten.getVarType (vt, v1)
      val _ = assert (Type.equals (resTy1, intTy), "getVarType should return the first set type")
      
      (* Second set (update) *)
      val _ = ShallowFlatten.setVarType (vt, v1, word32Ty)
      val resTy2 = ShallowFlatten.getVarType (vt, v1)
      val _ = assert (Type.equals (resTy2, word32Ty), "getVarType should return the updated type")

      val _ = ShallowFlatten.destroyVarTypes vt
   in () end)

   val _ = summarize ()
end
