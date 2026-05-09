local
   open Ssa
in
   (* Test 1: Simple program *)
   val _ = let
      val _ = print "Test 1: Simple program\n"
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
      val _ = print "Test 1 passed\n"
   in () end

   (* Test 2: rewriteBfs order and transformation *)
   val _ = let
      val _ = print "Test 2: rewriteBfs order and transformation\n"

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

      val _ = print "Visit order:\n"
      val _ = Vector.foreach (Vector.fromList visitOrder, fn s => print (s ^ "\n"))

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

      val _ = print "Test 2 passed\n"
   in () end

   (* Test 3: foreachBfs order *)
   val _ = let
      val _ = print "Test 3: foreachBfs order\n"

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

      val _ = print "Visit order:\n"
      val _ = Vector.foreach (Vector.fromList visitOrder, fn s => print (s ^ "\n"))

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

      val _ = print "Test 3 passed\n"
   in () end

   (* Test 4: maybeFlattenType *)
   val _ = let
      val _ = print "Test 4: maybeFlattenType\n"
      
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
      check (tuple2Ty, NONE, "tuple but not array");
      
      print "Test 4 passed\n"
   end

end
