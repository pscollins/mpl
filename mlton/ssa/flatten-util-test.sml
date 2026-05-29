local
   open Ssa
   open FlattenUtil
in
   val _ = runTest ("Test 1: basic maps", fn () => let
      val f1Name = Func.fromString "f1"
      val f1Label = Label.fromString "L1"
      val f1Label2 = Label.fromString "L1_2"
      val f1Block = Block.T {
         args = Vector.new0 (),
         label = f1Label,
         statements = Vector.new0 (),
         transfer = Transfer.Goto {args = Vector.new0 (), dst = f1Label2}
      }
      val f1Block2 = Block.T {
         args = Vector.new0 (),
         label = f1Label2,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f1Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f1Block, f1Block2],
         inline = InlineAttr.Auto,
         name = f1Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f1Label
      }

      val f2Name = Func.fromString "f2"
      val f2Label = Label.fromString "L2"
      val f2Block = Block.T {
         args = Vector.new0 (),
         label = f2Label,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f2Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f2Block],
         inline = InlineAttr.Auto,
         name = f2Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f2Label
      }

      val f3Name = Func.fromString "f3"
      val f3Label = Label.fromString "L3"
      val f3Label2 = Label.fromString "L3_2"
      val f3Block = Block.T {
         args = Vector.new0 (),
         label = f3Label,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.new0 (),
            func = f1Name,
            inline = InlineAttr.Auto,
            return = Return.NonTail {cont = f3Label2, handler = Handler.Caller}
         }
      }
      val f3Block2 = Block.T {
         args = Vector.new0 (),
         label = f3Label2,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.new0 (),
            func = f2Name,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val f3Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f3Block, f3Block2],
         inline = InlineAttr.Auto,
         name = f3Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f3Label
      }

      val f4Name = Func.fromString "f4"
      val f4Label = Label.fromString "L4"
      val f4Block = Block.T {
         args = Vector.new0 (),
         label = f4Label,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.new0 (),
            func = f4Name,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val f4Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f4Block],
         inline = InlineAttr.Auto,
         name = f4Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f4Label
      }

      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [f1Function, f2Function, f3Function, f4Function],
         globals = Vector.new0 (),
         main = f1Name
      }

      val seen = ref []
      val _ = foreachFunction (p, fn f => seen := Function.name f :: !seen)
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f1Name)), "f1 not seen")
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f2Name)), "f2 not seen")
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f3Name)), "f3 not seen")
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f4Name)), "f4 not seen")
      val _ = assert (List.length (!seen) = 4, "Wrong number of functions seen")

      val {getFunc, getBlock, getCallees, destroyFuncsMap} = newFuncsMap p
      
      val _ = assert (Func.equals (Function.name (getFunc f1Name), f1Name), "getFunc f1 failed")
      val _ = assert (Func.equals (Function.name (getFunc f2Name), f2Name), "getFunc f2 failed")
      
      val _ = assert (Label.equals (Block.label (getBlock f1Label), f1Label), "getBlock f1Label failed")
      val _ = assert (Label.equals (Block.label (getBlock f1Label2), f1Label2), "getBlock f1Label2 failed")
      val _ = assert (Label.equals (Block.label (getBlock f2Label), f2Label), "getBlock f2Label failed")

      fun hasCallee (callees, name) = Vector.exists (callees, fn n => Func.equals (n, name))
      
      val f1Callees = getCallees f1Name
      val _ = assert (Vector.length f1Callees = 0, "f1 should have no callees")
      
      val f2Callees = getCallees f2Name
      val _ = assert (Vector.length f2Callees = 0, "f2 should have no callees")
      
      val f3Callees = getCallees f3Name
      val _ = assert (hasCallee (f3Callees, f1Name), "f3 should call f1")
      val _ = assert (hasCallee (f3Callees, f2Name), "f3 should call f2")
      val _ = assert (Vector.length f3Callees = 2, "f3 should have 2 callees")
      
      val f4Callees = getCallees f4Name
      val _ = assert (hasCallee (f4Callees, f4Name), "f4 should call f4")
      val _ = assert (Vector.length f4Callees = 1, "f4 should have 1 callee")
      
      val _ = destroyFuncsMap()
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
         visited := s :: (!visited)
      )

      val rewriter: rewriter = {
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
         doTransfer = fn (_, t) => (
            log ("Transfer: " ^ (Layout.toString (Transfer.layout t)));
            t
         )
      }

      val _ = rewriteBfs rewriter p
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
         visited := s :: (!visited)
      )

      val visitor: visitor = {
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

      val _ = foreachBfs visitor p
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

   val _ = summarize ()
end
