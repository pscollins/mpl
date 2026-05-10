local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg
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

   (* Test 6: maybeFlattenArg *)
   val _ = runTest ("Test 6: maybeFlattenArg", fn () => let
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

   (* Test 7: maybeFlattenStatement *)
   val _ = runTest ("Test 7: maybeFlattenStatement", fn () => let
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
      val _ = assert (Vector.length stmts = 3, "s3 should flatten to 3 statements")

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
   in () end)

   val _ = summarize ()
end
