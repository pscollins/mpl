structure Atoms = Atoms ()
structure BackendAtoms = BackendAtoms (open Atoms)
structure Rssa = Rssa (open BackendAtoms)
structure TraceHeapOps = TraceHeapOps (Rssa)

local
   open Rssa

   fun assert (cond, msg) =
      if cond then () else (print ("Assertion failed: " ^ msg ^ "\n"); raise Fail msg)

   val word32 = Type.word WordSize.word32
   
   fun newVar () = (Var.newNoname (), word32)
   
   fun move (dst, src) = Statement.Move {
      dst = Operand.Var {ty = #2 dst, var = #1 dst},
      src = Operand.Var {ty = #2 src, var = #1 src}
   }
   
   fun primAdd (dst, arg1, arg2) = Statement.PrimApp {
      args = Vector.fromList [Operand.Var {ty = #2 arg1, var = #1 arg1},
                             Operand.Var {ty = #2 arg2, var = #1 arg2}],
      dst = SOME dst,
      prim = Prim.Word_add WordSize.word32
   }

   fun traceNoHeap (dst, arg) = Statement.PrimApp {
      args = Vector.fromList [arg],
      dst = SOME dst,
      prim = Prim.Trace_noHeap
   }

   fun traceHeapOk (dst, arg) = Statement.PrimApp {
      args = Vector.fromList [arg],
      dst = SOME dst,
      prim = Prim.Trace_heapOK
   }

   fun traceNoTuple (dst, arg) = Statement.PrimApp {
      args = Vector.fromList [arg],
      dst = SOME dst,
      prim = Prim.Trace_noTuple
   }

   fun profile () = Statement.Profile (ProfileExp.Enter SourceInfo.unknown)

   fun mkBlock (label, stmts, transfer) =
      Block.T {
         args = Vector.new0 (),
         kind = Kind.Jump,
         label = label,
         statements = Vector.fromList stmts,
         transfer = transfer
      }

   fun mkFunction (name, start, blocks) =
      Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList blocks,
         name = name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = start
      }

   val _ = print "Running TraceHeapOps.isForbiddenHeapOperand tests...\n"

   (* Test 1: Non-heap-accessing operands *)
   val _ = let
      val _ = print "Test 1: Non-heap-accessing operands\n"
      val v1 = newVar ()
      
      (* Var *)
      val opVar = Operand.Var {ty = #2 v1, var = #1 v1}
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOperand opVar), "Var should NOT be forbidden")
      
      (* Const *)
      val opConst = Operand.bool true
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOperand opConst), "Const should NOT be forbidden")
      
      (* Cast *)
      val opCast = Operand.Cast (opVar, #2 v1)
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOperand opCast), "Cast should NOT be forbidden")

      (* null *)
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOperand Operand.null), "null should NOT be forbidden")

      (* Nested Cast *)
      val opNestedCast = Operand.Cast (Operand.Offset {base = opVar, offset = Bytes.fromInt 0, ty = #2 v1}, #2 v1)
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOperand opNestedCast), "Nested Cast should NOT be forbidden (shallow check)")
   in () end

   (* Test 2: Heap-accessing operands *)
   val _ = let
      val _ = print "Test 2: Heap-accessing operands\n"
      val v1 = newVar ()
      val opVar = Operand.Var {ty = #2 v1, var = #1 v1}
      
      (* GCState *)
      val _ = assert (TraceHeapOps.isForbiddenHeapOperand Operand.GCState, "GCState SHOULD be forbidden")
      
      (* Offset *)
      val opOffset = Operand.Offset {base = opVar, offset = Bytes.fromInt 0, ty = #2 v1}
      val _ = assert (TraceHeapOps.isForbiddenHeapOperand opOffset, "Offset SHOULD be forbidden")
      
      (* ObjptrTycon *)
      val opObjptrTycon = Operand.ObjptrTycon ObjptrTycon.fill0Normal
      val _ = assert (TraceHeapOps.isForbiddenHeapOperand opObjptrTycon, "ObjptrTycon SHOULD be forbidden")
      
      (* Runtime *)
      val opRuntime = Operand.Runtime Runtime.GCField.ExnStack
      val _ = assert (TraceHeapOps.isForbiddenHeapOperand opRuntime, "Runtime SHOULD be forbidden")

      (* SequenceOffset *)
      val opSeqOffset = Operand.SequenceOffset {
         base = opVar,
         index = Operand.zero WordSize.word32,
         offset = Bytes.fromInt 0,
         scale = Scale.One,
         ty = #2 v1
      }
      val _ = assert (TraceHeapOps.isForbiddenHeapOperand opSeqOffset, "SequenceOffset SHOULD be forbidden")

      (* Address *)
      val opAddress = Operand.Address opOffset
      val _ = assert (TraceHeapOps.isForbiddenHeapOperand opAddress, "Address SHOULD be forbidden")
   in () end

   val _ = print "TraceHeapOps.isForbiddenHeapOperand tests finished.\n"

   val _ = print "Running TraceHeapOps.isForbiddenTupleOperand tests...\n"

   (* Test 1: Non-tuple-accessing operands *)
   val _ = let
      val _ = print "Test 1: Non-tuple-accessing operands\n"
      val v1 = newVar ()
      
      (* Var *)
      val opVar = Operand.Var {ty = #2 v1, var = #1 v1}
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOperand opVar), "Var should NOT be tuple-accessing")
      
      (* Const *)
      val opConst = Operand.bool true
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOperand opConst), "Const should NOT be tuple-accessing")
      
      (* Cast *)
      val opCast = Operand.Cast (opVar, #2 v1)
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOperand opCast), "Cast should NOT be tuple-accessing")

      (* GCState *)
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOperand Operand.GCState), "GCState should NOT be tuple-accessing")

      (* ObjptrTycon *)
      val opObjptrTycon = Operand.ObjptrTycon ObjptrTycon.fill0Normal
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOperand opObjptrTycon), "ObjptrTycon should NOT be tuple-accessing")
   in () end

   (* Test 2: Tuple-accessing operands *)
   val _ = let
      val _ = print "Test 2: Tuple-accessing operands\n"
      val v1 = newVar ()
      val opVar = Operand.Var {ty = #2 v1, var = #1 v1}
      
      (* Offset *)
      val opOffset = Operand.Offset {base = opVar, offset = Bytes.fromInt 0, ty = #2 v1}
      val _ = assert (TraceHeapOps.isForbiddenTupleOperand opOffset, "Offset SHOULD be tuple-accessing")
   in () end

   val _ = print "TraceHeapOps.isForbiddenTupleOperand tests finished.\n"

   val _ = print "Running TraceHeapOps.filterStatements tests...\n"

   (* Test 1: Empty program *)
   val _ = let
      val _ = print "Test 1: Empty program\n"
      val mainLabel = Label.newNoname ()
      val mainFunc = Func.newNoname ()
      val mainBlock = mkBlock (mainLabel, [], Transfer.Return (Vector.new0 ()))
      val mainFunction = mkFunction (mainFunc, mainLabel, [mainBlock])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = mainFunction,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val stmts = TraceHeapOps.filterStatements (p, fn _ => true)
      val _ = assert (List.length stmts = 0, "Empty program should have 0 statements")
   in () end

   (* Test 2: Single function, multiple blocks, multiple statements *)
   val _ = let
      val _ = print "Test 2: Single function, multiple blocks\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val v3 = newVar ()
      
      val s1 = move (v1, v2)
      val s2 = primAdd (v3, v1, v2)
      val s3 = move (v2, v3)
      val s4 = profile ()
      
      val l1 = Label.newNoname ()
      val l2 = Label.newNoname ()
      
      val b1 = mkBlock (l1, [s1, s2], Transfer.Goto {args = Vector.new0 (), dst = l2})
      val b2 = mkBlock (l2, [s3, s4], Transfer.Return (Vector.new0 ()))
      
      val f = mkFunction (Func.newNoname (), l1, [b1, b2])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val allStmts = TraceHeapOps.filterStatements (p, fn _ => true)
      val _ = assert (List.length allStmts = 4, "Should find 4 statements in total")
      
      val moveStmts = TraceHeapOps.filterStatements (p, fn s => 
         case s of Statement.Move _ => true | _ => false)
      val _ = assert (List.length moveStmts = 2, "Should find 2 move statements")

      val primStmts = TraceHeapOps.filterStatements (p, fn s => 
         case s of Statement.PrimApp _ => true | _ => false)
      val _ = assert (List.length primStmts = 1, "Should find 1 primapp statement")

      val profileStmts = TraceHeapOps.filterStatements (p, fn s => 
         case s of Statement.Profile _ => true | _ => false)
      val _ = assert (List.length profileStmts = 1, "Should find 1 profile statement")
   in () end

   (* Test 3: Multiple functions *)
   val _ = let
      val _ = print "Test 3: Multiple functions\n"
      val v1 = newVar ()
      val s1 = move (v1, v1)
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])

      val v2 = newVar ()
      val s2 = move (v2, v2)
      val l2 = Label.newNoname ()
      val b2 = mkBlock (l2, [s2], Transfer.Return (Vector.new0 ()))
      val f2 = mkFunction (Func.newNoname (), l2, [b2])
      
      val p = Program.T {
          functions = [f1],
          handlesSignals = false,
          main = f2,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val allStmts = TraceHeapOps.filterStatements (p, fn _ => true)
      val _ = assert (List.length allStmts = 2, "Should find 2 statements across functions")
   in () end

   (* Test 4: Mixed IR constructs *)
   val _ = let
      val _ = print "Test 4: Mixed IR constructs\n"
      val v1 = newVar ()
      val s1 = Statement.SetExnStackLocal
      val s2 = Statement.SetExnStackSlot
      val s3 = profile ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2, s3], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val exnStmts = TraceHeapOps.filterStatements (p, fn s => 
         case s of 
            Statement.SetExnStackLocal => true 
          | Statement.SetExnStackSlot => true 
          | _ => false)
      val _ = assert (List.length exnStmts = 2, "Should find 2 exn stack statements")
   in () end

   val _ = print "TraceHeapOps.filterStatements tests finished.\n"

   val _ = print "Running TraceHeapOps.mapStatements tests...\n"

   (* Test 1: Identity mapping (all NONE) *)
   val _ = let
      val _ = print "Test 1: Identity mapping (all NONE)\n"
      val v1 = newVar ()
      val s1 = move (v1, v1)
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val p' = TraceHeapOps.mapStatements (p, fn _ => NONE)
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 1, "Should still have 1 statement")
   in () end

   (* Test 2: Replace all statements *)
   val _ = let
      val _ = print "Test 2: Replace all statements\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = move (v1, v1)
      val s2 = profile ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val sReplacement = move (v2, v2)
      val p' = TraceHeapOps.mapStatements (p, fn _ => SOME sReplacement)
      
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 2, "Should have 2 statements")
      val allReplaced = List.forall (stmts, fn s => 
         case s of 
            Statement.Move {dst, src} => 
               (case (dst, src) of
                  (Operand.Var {var = v2_dst, ...}, Operand.Var {var = v2_src, ...}) => 
                     Var.equals (v2_dst, #1 v2) andalso Var.equals (v2_src, #1 v2)
                | _ => false)
          | _ => false)
      val _ = assert (allReplaced, "All statements should have been replaced by the move")
   in () end

   (* Test 3: Partial mapping (selective replacement) *)
   val _ = let
      val _ = print "Test 3: Partial mapping (selective replacement)\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = move (v1, v1)
      val s2 = profile ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val sReplacement = move (v2, v2)
      val p' = TraceHeapOps.mapStatements (p, fn s => 
         case s of 
            Statement.Profile _ => SOME sReplacement
          | _ => NONE)
      
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 2, "Should have 2 statements")
      
      val hasMove1 = List.exists (stmts, fn s => 
         case s of 
            Statement.Move {dst, ...} => 
               (case dst of Operand.Var {var, ...} => Var.equals (var, #1 v1) | _ => false)
          | _ => false)
      val hasMove2 = List.exists (stmts, fn s => 
         case s of 
            Statement.Move {dst, ...} => 
               (case dst of Operand.Var {var, ...} => Var.equals (var, #1 v2) | _ => false)
          | _ => false)
      val hasProfile = List.exists (stmts, fn s => 
         case s of Statement.Profile _ => true | _ => false)
      
      val _ = assert (hasMove1, "Should still have the first move")
      val _ = assert (hasMove2, "Should have the replacement move")
      val _ = assert (not hasProfile, "Should NOT have the profile statement")
   in () end

   (* Test 4: Multiple functions and blocks *)
   val _ = let
      val _ = print "Test 4: Multiple functions and blocks\n"
      val v1 = newVar ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [profile ()], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])

      val l2 = Label.newNoname ()
      val b2 = mkBlock (l2, [profile ()], Transfer.Return (Vector.new0 ()))
      val f2 = mkFunction (Func.newNoname (), l2, [b2])
      
      val p = Program.T {
          functions = [f1],
          handlesSignals = false,
          main = f2,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val sReplacement = move (v1, v1)
      val p' = TraceHeapOps.mapStatements (p, fn _ => SOME sReplacement)
      
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 2, "Should have 2 statements across functions")
      val allMoves = List.forall (stmts, fn s => 
         case s of Statement.Move _ => true | _ => false)
      val _ = assert (allMoves, "All statements should be moves now")
   in () end

   (* Test 5: Variety of IR constructs *)
   val _ = let
      val _ = print "Test 5: Variety of IR constructs\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = move (v1, v1)
      val s2 = primAdd (v1, v1, v1)
      val s3 = Statement.SetExnStackLocal
      val s4 = Statement.SetExnStackSlot
      val s5 = profile ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2, s3, s4, s5], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      (* Replace all except Move *)
      val p' = TraceHeapOps.mapStatements (p, fn s => 
         case s of 
            Statement.Move _ => NONE
          | _ => SOME (move (v2, v2)))
          
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 5, "Should have 5 statements")
      
      val numMovesV1 = List.length (List.keepAll (stmts, fn s => 
         case s of 
            Statement.Move {dst = Operand.Var {var, ...}, ...} => Var.equals (var, #1 v1)
          | _ => false))
      val numMovesV2 = List.length (List.keepAll (stmts, fn s => 
         case s of 
            Statement.Move {dst = Operand.Var {var, ...}, ...} => Var.equals (var, #1 v2)
          | _ => false))
          
      val _ = assert (numMovesV1 = 1, "Should have 1 move to v1 (the original)")
      val _ = assert (numMovesV2 = 4, "Should have 4 moves to v2 (the replacements)")
   in () end

   (* Test 6: Bind and SetSlotExnStack constructs *)
   val _ = let
      val _ = print "Test 6: Bind and SetSlotExnStack constructs\n"
      val v1 = newVar ()
      
      val s1 = Statement.Bind {
         dst = v1,
         pinned = false,
         src = Operand.bool true
      }
      val s2 = Statement.SetSlotExnStack
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val p' = TraceHeapOps.mapStatements (p, fn s => 
         case s of 
            Statement.Bind _ => SOME (profile ())
          | Statement.SetSlotExnStack => SOME (profile ())
          | _ => NONE)
          
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 2, "Should have 2 statements")
      val allProfiles = List.forall (stmts, fn s => 
         case s of Statement.Profile _ => true | _ => false)
      val _ = assert (allProfiles, "All statements should be profile statements now")
   in () end

   val _ = print "TraceHeapOps.mapStatements tests finished.\n"

   val _ = print "Running TraceHeapOps.foldStatements tests...\n"

   (* Test 1: Empty program *)
   val _ = let
      val _ = print "Test 1: Empty program\n"
      val mainLabel = Label.newNoname ()
      val mainFunc = Func.newNoname ()
      val mainBlock = mkBlock (mainLabel, [], Transfer.Return (Vector.new0 ()))
      val mainFunction = mkFunction (mainFunc, mainLabel, [mainBlock])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = mainFunction,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val count = TraceHeapOps.foldStatements (p, 0, fn (_, acc) => acc + 1)
      val _ = assert (count = 0, "Empty program should have 0 statements")
   in () end

   (* Test 2: Count statements *)
   val _ = let
      val _ = print "Test 2: Count statements\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = move (v1, v2)
      val s2 = profile ()
      val s3 = move (v2, v1)
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2, s3], Transfer.Return (Vector.new0 ()))
      val f = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val count = TraceHeapOps.foldStatements (p, 0, fn (_, acc) => acc + 1)
      val _ = assert (count = 3, "Should have 3 statements")
   in () end

   (* Test 3: Collect all statements *)
   val _ = let
      val _ = print "Test 3: Collect all statements\n"
      val v1 = newVar ()
      val s1 = move (v1, v1)
      val s2 = profile ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val stmts = TraceHeapOps.foldStatements (p, [], fn (s, acc) => s :: acc)
      val _ = assert (List.length stmts = 2, "Should have collected 2 statements")
      
      val hasMove = List.exists (stmts, fn s => case s of Statement.Move _ => true | _ => false)
      val hasProfile = List.exists (stmts, fn s => case s of Statement.Profile _ => true | _ => false)
      val _ = assert (hasMove andalso hasProfile, "Should have both move and profile")
   in () end

   (* Test 4: Multiple functions and blocks *)
   val _ = let
      val _ = print "Test 4: Multiple functions and blocks\n"
      val v1 = newVar ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [profile ()], Transfer.Goto {args = Vector.new0 (), dst = l1}) (* Infinite loop block *)
      val l2 = Label.newNoname ()
      val b2 = mkBlock (l2, [profile (), profile ()], Transfer.Return (Vector.new0 ()))
      
      val f1 = mkFunction (Func.newNoname (), l1, [b1, b2])

      val l3 = Label.newNoname ()
      val b3 = mkBlock (l3, [profile ()], Transfer.Return (Vector.new0 ()))
      val f2 = mkFunction (Func.newNoname (), l3, [b3])
      
      val p = Program.T {
          functions = [f1],
          handlesSignals = false,
          main = f2,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val count = TraceHeapOps.foldStatements (p, 0, fn (_, acc) => acc + 1)
      val _ = assert (count = 4, "Should find 4 statements across functions and blocks")
   in () end

   (* Test 5: Sum specific statement types *)
   val _ = let
      val _ = print "Test 5: Sum specific statement types\n"
      val v1 = newVar ()
      val s1 = move (v1, v1)
      val s2 = primAdd (v1, v1, v1)
      val s3 = move (v1, v1)
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2, s3], Transfer.Return (Vector.new0 ()))
      val f = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val moveCount = TraceHeapOps.foldStatements (p, 0, fn (s, acc) => 
         case s of Statement.Move _ => acc + 1 | _ => acc)
      val _ = assert (moveCount = 2, "Should have 2 move statements")
      
      val primCount = TraceHeapOps.foldStatements (p, 0, fn (s, acc) => 
         case s of Statement.PrimApp _ => acc + 1 | _ => acc)
      val _ = assert (primCount = 1, "Should have 1 primapp statement")
   in () end

   val _ = print "TraceHeapOps.foldStatements tests finished.\n"

   val _ = print "Running TraceHeapOps.isForbiddenHeapOp tests...\n"

   val emptySet = TraceHeapOps.VarSet.empty

   (* Test 1: Non-PrimApp statements should return false *)
   val _ = let
      val _ = print "Test 1: Non-PrimApp statements\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = move (v1, v2)
      val s2 = profile ()
      val s3 = Statement.SetExnStackLocal
      val s4 = Statement.Bind { dst = v1, pinned = false, src = Operand.Var {ty = #2 v2, var = #1 v2} }
      val s5 = Statement.SetSlotExnStack
      
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s1), "Move should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s2), "Profile should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s3), "SetExnStackLocal should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s4), "Bind should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s5), "SetSlotExnStack should not be forbidden")
   in () end

   (* Test 2: Non-Trace_noHeap PrimApps should return false *)
   val _ = let
      val _ = print "Test 2: Non-Trace_noHeap PrimApps\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = primAdd (v1, v2, v2)
      
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s1), "Word_add should not be forbidden")
   in () end

   (* Test 3: Trace_noHeap with Var, Const, or Cast operand should return false *)
   val _ = let
      val _ = print "Test 3: Trace_noHeap with Var, Const, or Cast operand\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      (* Var operand *)
      val s1 = traceNoHeap (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      (* Const operand *)
      val s2 = traceNoHeap (v1, Operand.bool true)
      
      (* Cast(Var) operand *)
      val castOp = Operand.Cast (Operand.Var {ty = #2 v2, var = #1 v2}, #2 v2)
      val s3 = traceNoHeap (v1, castOp)

      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s1), "Trace_noHeap with Var should NOT be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s2), "Trace_noHeap with Const should NOT be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp emptySet s3), "Trace_noHeap with Cast should NOT be forbidden")
   in () end

   (* Test 4: Trace_noHeap with heap-accessing operands should return true *)
   val _ = let
      val _ = print "Test 4: Trace_noHeap with heap-accessing operands\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      (* Offset operand *)
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         offset = Bytes.fromInt 0,
         ty = #2 v2
      }
      val s1 = traceNoHeap (v1, offsetOp)

      (* GCState operand *)
      val s2 = traceNoHeap (v1, Operand.GCState)

      (* SequenceOffset operand *)
      val seqOffsetOp = Operand.SequenceOffset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         index = Operand.zero WordSize.word32,
         offset = Bytes.fromInt 0,
         scale = Scale.One,
         ty = #2 v2
      }
      val s3 = traceNoHeap (v1, seqOffsetOp)

      val _ = assert (TraceHeapOps.isForbiddenHeapOp emptySet s1, "Trace_noHeap with Offset SHOULD be forbidden")
      val _ = assert (TraceHeapOps.isForbiddenHeapOp emptySet s2, "Trace_noHeap with GCState SHOULD be forbidden")
      val _ = assert (TraceHeapOps.isForbiddenHeapOp emptySet s3, "Trace_noHeap with SequenceOffset SHOULD be forbidden")
   in () end

   (* Test 5: Trace_noHeap with Var operand that is in the VarSet *)
   val _ = let
      val _ = print "Test 5: Trace_noHeap with Var operand in VarSet\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val vs = TraceHeapOps.VarSet.add (TraceHeapOps.VarSet.empty, #1 v2)
      val s1 = traceNoHeap (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      val _ = assert (TraceHeapOps.isForbiddenHeapOp vs s1, "Trace_noHeap with Var in VarSet SHOULD be forbidden")
   in () end

   val _ = print "TraceHeapOps.isForbiddenHeapOp tests finished.\n"

   val _ = print "Running TraceHeapOps.isForbiddenTupleOp tests...\n"

   (* Test 1: Non-PrimApp statements should return false *)
   val _ = let
      val _ = print "Test 1: Non-PrimApp statements\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = move (v1, v2)
      val s2 = profile ()
      val s3 = Statement.SetExnStackLocal
      val s4 = Statement.Bind { dst = v1, pinned = false, src = Operand.Var {ty = #2 v2, var = #1 v2} }
      
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s1), "Move should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s2), "Profile should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s3), "SetExnStackLocal should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s4), "Bind should not be forbidden")
   in () end

   (* Test 2: Non-Trace_noTuple PrimApps should return false *)
   val _ = let
      val _ = print "Test 2: Non-Trace_noTuple PrimApps\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = primAdd (v1, v2, v2)
      val s2 = traceNoHeap (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s1), "Word_add should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s2), "Trace_noHeap should not be forbidden")
   in () end

   (* Test 3: Trace_noTuple with Var, Const, or Cast operand should return false *)
   val _ = let
      val _ = print "Test 3: Trace_noTuple with Var, Const, or Cast operand\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      (* Var operand *)
      val s1 = traceNoTuple (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      (* Const operand *)
      val s2 = traceNoTuple (v1, Operand.bool true)
      
      (* Cast(Var) operand *)
      val castOp = Operand.Cast (Operand.Var {ty = #2 v2, var = #1 v2}, #2 v2)
      val s3 = traceNoTuple (v1, castOp)

      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s1), "Trace_noTuple with Var should NOT be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s2), "Trace_noTuple with Const should NOT be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenTupleOp emptySet s3), "Trace_noTuple with Cast should NOT be forbidden")
   in () end

   (* Test 4: Trace_noTuple with tuple-accessing operands should return true *)
   val _ = let
      val _ = print "Test 4: Trace_noTuple with tuple-accessing operands\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      (* Offset operand *)
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         offset = Bytes.fromInt 0,
         ty = #2 v2
      }
      val s1 = traceNoTuple (v1, offsetOp)

      val _ = assert (TraceHeapOps.isForbiddenTupleOp emptySet s1, "Trace_noTuple with Offset SHOULD be forbidden")
   in () end

   (* Test 5: Trace_noTuple with Var operand that is in the VarSet *)
   val _ = let
      val _ = print "Test 5: Trace_noTuple with Var operand in VarSet\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val vs = TraceHeapOps.VarSet.add (TraceHeapOps.VarSet.empty, #1 v2)
      val s1 = traceNoTuple (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      val _ = assert (TraceHeapOps.isForbiddenTupleOp vs s1, "Trace_noTuple with Var in VarSet SHOULD be forbidden")
   in () end

   val _ = print "TraceHeapOps.isForbiddenTupleOp tests finished.\n"

   val _ = print "Running TraceHeapOps.maybeElideNoHeap tests...\n"

   (* Test 1: Trace_noHeap with Var operand *)
   val _ = let
      val _ = print "Test 1: Trace_noHeap with Var operand\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s = traceNoHeap (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      val res = TraceHeapOps.maybeElideNoHeap s
      val _ = case res of
         SOME (Statement.Bind {dst, src, pinned}) =>
            let
               val _ = assert (Var.equals (#1 dst, #1 v1), "Bind dst should match Trace_noHeap dst")
               val _ = assert (not pinned, "Bind should not be pinned")
               val _ = case src of
                  Operand.Var {var, ...} => assert (Var.equals (var, #1 v2), "Bind src should match Trace_noHeap arg")
                | _ => assert (false, "Bind src should be a Var")
            in () end
       | _ => assert (false, "Should have returned SOME Bind")
   in () end

   (* Test 2: Trace_noHeap with Const operand *)
   val _ = let
      val _ = print "Test 2: Trace_noHeap with Const operand\n"
      val v1 = newVar ()
      val s = traceNoHeap (v1, Operand.bool true)
      
      val res = TraceHeapOps.maybeElideNoHeap s
      val _ = case res of
         SOME (Statement.Bind {dst, src, ...}) =>
            let
               val _ = assert (Var.equals (#1 dst, #1 v1), "Bind dst should match Trace_noHeap dst")
               val _ = case src of
                  Operand.Const _ => () (* Should check value but Const.t is abstract-ish here *)
                | _ => assert (false, "Bind src should be a Const")
            in () end
       | _ => assert (false, "Should have returned SOME Bind")
   in () end

   (* Test 3: Trace_noHeap with Offset operand *)
   val _ = let
      val _ = print "Test 3: Trace_noHeap with Offset operand\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         offset = Bytes.fromInt 0,
         ty = #2 v2
      }
      val s = traceNoHeap (v1, offsetOp)
      
      val res = TraceHeapOps.maybeElideNoHeap s
      val _ = case res of
         SOME (Statement.Bind {dst, src, ...}) =>
            let
               val _ = assert (Var.equals (#1 dst, #1 v1), "Bind dst should match")
               val _ = case src of
                  Operand.Offset _ => ()
                | _ => assert (false, "Bind src should be an Offset")
            in () end
       | _ => assert (false, "Should have returned SOME Bind")
   in () end

   (* Test 4: Other PrimApp (not Trace_noHeap) *)
   val _ = let
      val _ = print "Test 4: Other PrimApp\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s = primAdd (v1, v2, v2)
      
      val res = TraceHeapOps.maybeElideNoHeap s
      val _ = assert (Option.isNone res, "Should NOT elide non-Trace_noHeap PrimApp")
   in () end

   (* Test 5: Move statement *)
   val _ = let
      val _ = print "Test 5: Move statement\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s = move (v1, v2)
      
      val res = TraceHeapOps.maybeElideNoHeap s
      val _ = assert (Option.isNone res, "Should NOT elide Move statement")
   in () end

   (* Test 6: Profile statement *)
   val _ = let
      val _ = print "Test 6: Profile statement\n"
      val s = profile ()
      val res = TraceHeapOps.maybeElideNoHeap s
      val _ = assert (Option.isNone res, "Should NOT elide Profile statement")
   in () end

   (* Test 7: Trace_noHeap without destination should raise Fail *)
   val _ = let
      val _ = print "Test 7: Trace_noHeap without destination\n"
      val v2 = newVar ()
      val s = Statement.PrimApp {
         args = Vector.fromList [Operand.Var {ty = #2 v2, var = #1 v2}],
         dst = NONE,
         prim = Prim.Trace_noHeap
      }
      val raised = (TraceHeapOps.maybeElideNoHeap s; false) handle Fail _ => true
      val _ = assert (raised, "Should raise Fail for Trace_noHeap without destination")
   in () end

   (* Test 8: Variety of IR constructs (SetExnStackLocal, etc.) *)
   val _ = let
      val _ = print "Test 8: Variety of IR constructs\n"
      val v1 = newVar ()
      
      val s1 = Statement.SetExnStackLocal
      val s2 = Statement.SetExnStackSlot
      val s3 = Statement.SetSlotExnStack
      val s4 = Statement.Object {
         dst = v1,
         obj = Object.Normal {
            init = Vector.new0 (),
            tycon = ObjptrTycon.fill0Normal
         }
      }
      (* SetHandler requires a label *)
      val l = Label.newNoname ()
      val s5 = Statement.SetHandler l
      
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideNoHeap s1), "Should NOT elide SetExnStackLocal")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideNoHeap s2), "Should NOT elide SetExnStackSlot")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideNoHeap s3), "Should NOT elide SetSlotExnStack")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideNoHeap s4), "Should NOT elide Object")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideNoHeap s5), "Should NOT elide SetHandler")
   in () end

   (* Test 9: Bind statement as input *)
   val _ = let
      val _ = print "Test 9: Bind statement as input\n"
      val v1 = newVar ()
      val s = Statement.Bind {
         dst = v1,
         pinned = false,
         src = Operand.bool true
      }
      val res = TraceHeapOps.maybeElideNoHeap s
      val _ = assert (Option.isNone res, "Should NOT elide Bind statement")
   in () end

   val _ = print "TraceHeapOps.maybeElideNoHeap tests finished.\n"

   val _ = print "Running TraceHeapOps.maybeElideHeapOk tests...\n"

   (* Test 1: Trace_heapOK with Var operand *)
   val _ = let
      val _ = print "Test 1: Trace_heapOK with Var operand\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s = traceHeapOk (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      val res = TraceHeapOps.maybeElideHeapOk s
      val _ = case res of
         SOME (Statement.Bind {dst, src, pinned}) =>
            let
               val _ = assert (Var.equals (#1 dst, #1 v1), "Bind dst should match Trace_heapOK dst")
               val _ = assert (not pinned, "Bind should not be pinned")
               val _ = case src of
                  Operand.Var {var, ...} => assert (Var.equals (var, #1 v2), "Bind src should match Trace_heapOK arg")
                | _ => assert (false, "Bind src should be a Var")
            in () end
       | _ => assert (false, "Should have returned SOME Bind")
   in () end

   (* Test 2: Trace_heapOK with Const operand *)
   val _ = let
      val _ = print "Test 2: Trace_heapOK with Const operand\n"
      val v1 = newVar ()
      val s = traceHeapOk (v1, Operand.bool true)
      
      val res = TraceHeapOps.maybeElideHeapOk s
      val _ = case res of
         SOME (Statement.Bind {dst, src, ...}) =>
            let
               val _ = assert (Var.equals (#1 dst, #1 v1), "Bind dst should match Trace_heapOK dst")
               val _ = case src of
                  Operand.Const _ => ()
                | _ => assert (false, "Bind src should be a Const")
            in () end
       | _ => assert (false, "Should have returned SOME Bind")
   in () end

   (* Test 3: Trace_heapOK with Offset operand *)
   val _ = let
      val _ = print "Test 3: Trace_heapOK with Offset operand\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         offset = Bytes.fromInt 0,
         ty = #2 v2
      }
      val s = traceHeapOk (v1, offsetOp)
      
      val res = TraceHeapOps.maybeElideHeapOk s
      val _ = case res of
         SOME (Statement.Bind {dst, src, ...}) =>
            let
               val _ = assert (Var.equals (#1 dst, #1 v1), "Bind dst should match")
               val _ = case src of
                  Operand.Offset _ => ()
                | _ => assert (false, "Bind src should be an Offset")
            in () end
       | _ => assert (false, "Should have returned SOME Bind")
   in () end

   (* Test 4: Other PrimApp (not Trace_heapOK) *)
   val _ = let
      val _ = print "Test 4: Other PrimApp\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s = primAdd (v1, v2, v2)
      
      val res = TraceHeapOps.maybeElideHeapOk s
      val _ = assert (Option.isNone res, "Should NOT elide non-Trace_heapOK PrimApp")
   in () end

   (* Test 5: Move statement *)
   val _ = let
      val _ = print "Test 5: Move statement\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s = move (v1, v2)
      
      val res = TraceHeapOps.maybeElideHeapOk s
      val _ = assert (Option.isNone res, "Should NOT elide Move statement")
   in () end

   (* Test 6: Profile statement *)
   val _ = let
      val _ = print "Test 6: Profile statement\n"
      val s = profile ()
      val res = TraceHeapOps.maybeElideHeapOk s
      val _ = assert (Option.isNone res, "Should NOT elide Profile statement")
   in () end

   (* Test 7: Trace_heapOK without destination should raise Fail *)
   val _ = let
      val _ = print "Test 7: Trace_heapOK without destination\n"
      val v2 = newVar ()
      val s = Statement.PrimApp {
         args = Vector.fromList [Operand.Var {ty = #2 v2, var = #1 v2}],
         dst = NONE,
         prim = Prim.Trace_heapOK
      }
      val raised = (TraceHeapOps.maybeElideHeapOk s; false) handle Fail _ => true
      val _ = assert (raised, "Should raise Fail for Trace_heapOK without destination")
   in () end

   (* Test 8: Variety of IR constructs (SetExnStackLocal, etc.) *)
   val _ = let
      val _ = print "Test 8: Variety of IR constructs\n"
      val v1 = newVar ()
      
      val s1 = Statement.SetExnStackLocal
      val s2 = Statement.SetExnStackSlot
      val s3 = Statement.SetSlotExnStack
      val s4 = Statement.Object {
         dst = v1,
         obj = Object.Normal {
            init = Vector.new0 (),
            tycon = ObjptrTycon.fill0Normal
         }
      }
      val l = Label.newNoname ()
      val s5 = Statement.SetHandler l
      
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideHeapOk s1), "Should NOT elide SetExnStackLocal")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideHeapOk s2), "Should NOT elide SetExnStackSlot")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideHeapOk s3), "Should NOT elide SetSlotExnStack")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideHeapOk s4), "Should NOT elide Object")
      val _ = assert (Option.isNone (TraceHeapOps.maybeElideHeapOk s5), "Should NOT elide SetHandler")
   in () end

   (* Test 9: Bind statement as input *)
   val _ = let
      val _ = print "Test 9: Bind statement as input\n"
      val v1 = newVar ()
      val s = Statement.Bind {
         dst = v1,
         pinned = false,
         src = Operand.bool true
      }
      val res = TraceHeapOps.maybeElideHeapOk s
      val _ = assert (Option.isNone res, "Should NOT elide Bind statement")
   in () end

   val _ = print "TraceHeapOps.maybeElideHeapOk tests finished.\n"

   val _ = print "Running TraceHeapOps.statementsToString tests...\n"

   val _ = let
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = move (v1, v2)
      val s2 = profile ()
      val str = TraceHeapOps.statementsToString [s1, s2]
      val _ = print ("Statements as string:\n" ^ str ^ "\n")
      (* We just check it's non-empty and contains some expected keywords *)
      val _ = assert (String.size str > 0, "String should not be empty")
   in () end

   val _ = print "TraceHeapOps.statementsToString tests finished.\n"

   val _ = print "Running TraceHeapOps.transform tests...\n"

   (* Test 1: Empty program *)
   val _ = let
      val _ = print "Test 1: Empty program\n"
      val mainLabel = Label.newNoname ()
      val mainFunc = Func.newNoname ()
      val mainBlock = mkBlock (mainLabel, [], Transfer.Return (Vector.new0 ()))
      val mainFunction = mkFunction (mainFunc, mainLabel, [mainBlock])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = mainFunction,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val _ = TraceHeapOps.transform p
   in () end

   (* Test 2: Program with no Trace_noHeap *)
   val _ = let
      val _ = print "Test 2: Program with no Trace_noHeap\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = move (v1, v2)
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val _ = TraceHeapOps.transform p
   in () end

   (* Test 3: Program with valid Trace_noHeap (should be elided) *)
   val _ = let
      val _ = print "Test 3: Program with valid Trace_noHeap\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = traceNoHeap (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val p' = TraceHeapOps.transform p
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 1, "Should have 1 statement")
      val isBind = case stmts of
                      s :: _ => (case s of Statement.Bind _ => true | _ => false)
                    | _ => false
      val _ = assert (isBind, "Trace_noHeap should have been elided to Bind")
   in () end

   (* Test 4: Program with forbidden Trace_noHeap (should raise error) *)
   val _ = let
      val _ = print "Test 4: Program with forbidden Trace_noHeap\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         offset = Bytes.fromInt 0,
         ty = #2 v2
      }
      val s1 = traceNoHeap (v1, offsetOp)
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val raised = (TraceHeapOps.transform p; false) handle _ => true
      val _ = assert (raised, "Forbidden heap op should have raised an error")
   in () end

   (* Test 5: Complex program with mixed constructs *)
   val _ = let
      val _ = print "Test 5: Complex program with mixed constructs\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = move (v1, v2)
      val s2 = traceNoHeap (v2, Operand.Var {ty = #2 v1, var = #1 v1})
      val s3 = profile ()
      val s4 = Statement.SetExnStackLocal
      val s_slot = Statement.SetExnStackSlot
      val l_handler = Label.newNoname ()
      val s5 = Statement.SetHandler l_handler
      val s6 = Statement.Bind { dst = v1, pinned = false, src = Operand.bool true }
      val s7 = Statement.SetSlotExnStack
      val s8 = Statement.Object {
         dst = v2,
         obj = Object.Normal {
            init = Vector.new0 (),
            tycon = ObjptrTycon.fill0Normal
         }
      }
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2, s3, s4, s_slot, s5, s6, s7, s8], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val p' = TraceHeapOps.transform p
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 9, "Should have 9 statements")
      
      val hasBindFromNoHeap = List.exists (stmts, fn s => 
         case s of 
            Statement.Bind {dst, ...} => Var.equals (#1 dst, #1 v2)
          | _ => false)
      val hasNoHeap = List.exists (stmts, fn s => 
         case s of Statement.PrimApp {prim = Prim.Trace_noHeap, ...} => true | _ => false)
      
      val _ = assert (hasBindFromNoHeap, "Should have a Bind (elided Trace_noHeap) for v2")
      val _ = assert (not hasNoHeap, "Should NOT have any Trace_noHeap left")
   in () end

   (* Test 6: Multiple functions and valid Trace_noHeap *)
   val _ = let
      val _ = print "Test 6: Multiple functions and valid Trace_noHeap\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = traceNoHeap (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])

      val s2 = traceNoHeap (v2, Operand.Var {ty = #2 v1, var = #1 v1})
      val l2 = Label.newNoname ()
      val b2 = mkBlock (l2, [s2], Transfer.Return (Vector.new0 ()))
      val f2 = mkFunction (Func.newNoname (), l2, [b2])
      
      val p = Program.T {
          functions = [f1],
          handlesSignals = false,
          main = f2,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val p' = TraceHeapOps.transform p
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 2, "Should have 2 statements across functions")
      val allBinds = List.forall (stmts, fn s => case s of Statement.Bind _ => true | _ => false)
      val _ = assert (allBinds, "All Trace_noHeap should have been elided to Bind")
   in () end

   (* Test 7: Program with valid Trace_heapOK (should be elided) *)
   val _ = let
      val _ = print "Test 7: Program with valid Trace_heapOK\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = traceHeapOk (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val p' = TraceHeapOps.transform p
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 1, "Should have 1 statement")
      val isBind = case stmts of
                      s :: _ => (case s of Statement.Bind _ => true | _ => false)
                    | _ => false
      val _ = assert (isBind, "Trace_heapOK should have been elided to Bind")
   in () end

   (* Test 8: Program with both Trace_noHeap and Trace_heapOK *)
   val _ = let
      val _ = print "Test 8: Program with both Trace_noHeap and Trace_heapOK\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = traceNoHeap (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      val s2 = traceHeapOk (v2, Operand.Var {ty = #2 v1, var = #1 v1})
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val p' = TraceHeapOps.transform p
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 2, "Should have 2 statements")
      val allBinds = List.forall (stmts, fn s => case s of Statement.Bind _ => true | _ => false)
      val _ = assert (allBinds, "Both Trace_noHeap and Trace_heapOK should have been elided to Bind")
   in () end

   (* Test 9: Variety of IR constructs and Trace_heapOK *)
   val _ = let
      val _ = print "Test 9: Variety of IR constructs and Trace_heapOK\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         offset = Bytes.fromInt 4,
         ty = #2 v2
      }
      val s1 = Statement.Move {
         dst = Operand.Var {ty = #2 v1, var = #1 v1},
         src = offsetOp
      }
      val s2 = traceHeapOk (v1, Operand.Var {ty = #2 v2, var = #1 v2})
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      
      val p' = TraceHeapOps.transform p
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 2, "Should have 2 statements")
      
      val hasMove = List.exists (stmts, fn s => case s of Statement.Move _ => true | _ => false)
      val hasBind = List.exists (stmts, fn s => case s of Statement.Bind _ => true | _ => false)
      
      val _ = assert (hasMove, "Should still have the Move statement")
      val _ = assert (hasBind, "Trace_heapOK should have been elided to Bind")
   in () end

   (* Test 10: Trace_heapOK with heap-accessing operand (should NOT be forbidden) *)
   val _ = let
      val _ = print "Test 10: Trace_heapOK with heap-accessing operand\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v2, var = #1 v2},
         offset = Bytes.fromInt 0,
         ty = #2 v2
      }
      val s1 = traceHeapOk (v1, offsetOp)
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      (* This should NOT raise an error *)
      val p' = TraceHeapOps.transform p
      val stmts = TraceHeapOps.filterStatements (p', fn _ => true)
      val _ = assert (List.length stmts = 1, "Should have 1 statement")
      val isBind = case stmts of
                      s :: _ => (case s of Statement.Bind _ => true | _ => false)
                    | _ => false
      val _ = assert (isBind, "Trace_heapOK with Offset should have been elided to Bind")
   in () end

   (* Test 11: Program with forbidden Trace_noHeap via alias *)
   val _ = let
      val _ = print "Test 11: Program with forbidden Trace_noHeap via alias\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val v3 = newVar ()
      
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v1, var = #1 v1},
         offset = Bytes.fromInt 0,
         ty = #2 v1
      }
      (* v2 becomes an alias for a heap-accessing operand *)
      val s1 = Statement.Bind { dst = v2, src = offsetOp, pinned = false }
      (* Trace_noHeap uses v2, which is forbidden *)
      val s2 = traceNoHeap (v3, Operand.Var {ty = #2 v2, var = #1 v2})
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val raised = (TraceHeapOps.transform p; false) handle _ => true
      val _ = assert (raised, "Forbidden heap op via alias should have raised an error")
   in () end

   val _ = print "TraceHeapOps.transform tests finished.\n"

   val _ = print "Running TraceHeapOps.collectForbiddenHeapVars tests...\n"

   (* Test 1: Empty program *)
   val _ = let
      val _ = print "Test 1: Empty program\n"
      val mainLabel = Label.newNoname ()
      val mainBlock = mkBlock (mainLabel, [], Transfer.Return (Vector.new0 ()))
      val mainFunction = mkFunction (Func.newNoname (), mainLabel, [mainBlock])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = mainFunction,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenHeapVars p
      val _ = assert (TraceHeapOps.VarSet.isEmpty vars, "Empty program should have no forbidden vars")
   in () end

   (* Test 2: Binds with non-heap-accessing operands *)
   val _ = let
      val _ = print "Test 2: Binds with non-heap-accessing operands\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val s1 = Statement.Bind { dst = v1, src = Operand.bool true, pinned = false }
      val s2 = Statement.Bind { dst = v2, src = Operand.Var {ty = #2 v1, var = #1 v1}, pinned = false }
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenHeapVars p
      val _ = assert (TraceHeapOps.VarSet.isEmpty vars, "Non-heap-accessing binds should not result in forbidden vars")
   in () end

   (* Test 3: Binds with heap-accessing operands *)
   val _ = let
      val _ = print "Test 3: Binds with heap-accessing operands\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val v3 = newVar ()
      
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v1, var = #1 v1},
         offset = Bytes.fromInt 0,
         ty = #2 v1
      }
      val s1 = Statement.Bind { dst = v2, src = offsetOp, pinned = false }
      val s2 = Statement.Bind { dst = v3, src = Operand.GCState, pinned = false }
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenHeapVars p
      val _ = assert (TraceHeapOps.VarSet.size vars = 2, "Should have 2 forbidden vars")
      val _ = assert (TraceHeapOps.VarSet.contains (vars, #1 v2), "v2 should be forbidden")
      val _ = assert (TraceHeapOps.VarSet.contains (vars, #1 v3), "v3 should be forbidden")
   in () end

   (* Test 4: Mixed binds and other statements *)
   val _ = let
      val _ = print "Test 4: Mixed binds and other statements\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val v3 = newVar ()
      
      val s1 = Statement.Bind { dst = v1, src = Operand.GCState, pinned = false }
      val s2 = move (v2, v1)
      val s3 = Statement.Bind { dst = v3, src = Operand.Var {ty = #2 v1, var = #1 v1}, pinned = false }
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2, s3], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenHeapVars p
      val _ = assert (TraceHeapOps.VarSet.size vars = 1, "Should have 1 forbidden var")
      val _ = assert (TraceHeapOps.VarSet.contains (vars, #1 v1), "v1 should be forbidden")
      val _ = assert (not (TraceHeapOps.VarSet.contains (vars, #1 v3)), "v3 should NOT be forbidden (it's a var-to-var bind)")
   in () end

   (* Test 5: Multiple functions and blocks *)
   val _ = let
      val _ = print "Test 5: Multiple functions and blocks\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [Statement.Bind { dst = v1, src = Operand.GCState, pinned = false }], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])

      val l2 = Label.newNoname ()
      val b2 = mkBlock (l2, [Statement.Bind { dst = v2, src = Operand.GCState, pinned = false }], Transfer.Return (Vector.new0 ()))
      val f2 = mkFunction (Func.newNoname (), l2, [b2])
      
      val p = Program.T {
          functions = [f1],
          handlesSignals = false,
          main = f2,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenHeapVars p
      val _ = assert (TraceHeapOps.VarSet.size vars = 2, "Should find 2 forbidden vars across functions")
      val _ = assert (TraceHeapOps.VarSet.contains (vars, #1 v1), "v1 should be forbidden")
      val _ = assert (TraceHeapOps.VarSet.contains (vars, #1 v2), "v2 should be forbidden")
   in () end

   val _ = print "TraceHeapOps.collectForbiddenHeapVars tests finished.\n"

   val _ = print "Running TraceHeapOps.collectForbiddenTupleVars tests...\n"

   (* Test 1: Empty program *)
   val _ = let
      val _ = print "Test 1: Empty program\n"
      val mainLabel = Label.newNoname ()
      val mainBlock = mkBlock (mainLabel, [], Transfer.Return (Vector.new0 ()))
      val mainFunction = mkFunction (Func.newNoname (), mainLabel, [mainBlock])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = mainFunction,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenTupleVars p
      val _ = assert (TraceHeapOps.VarSet.isEmpty vars, "Empty program should have no forbidden vars")
   in () end

   (* Test 2: Binds with non-tuple-accessing operands *)
   val _ = let
      val _ = print "Test 2: Binds with non-tuple-accessing operands\n"
      val v1 = newVar ()
      val s1 = Statement.Bind { dst = v1, src = Operand.bool true, pinned = false }
      val s2 = Statement.Bind { dst = newVar (), src = Operand.GCState, pinned = false }
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1, s2], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenTupleVars p
      val _ = assert (TraceHeapOps.VarSet.isEmpty vars, "Non-tuple-accessing binds should not result in forbidden vars")
   in () end

   (* Test 3: Binds with tuple-accessing operands *)
   val _ = let
      val _ = print "Test 3: Binds with tuple-accessing operands\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val offsetOp = Operand.Offset {
         base = Operand.Var {ty = #2 v1, var = #1 v1},
         offset = Bytes.fromInt 0,
         ty = #2 v1
      }
      val s1 = Statement.Bind { dst = v2, src = offsetOp, pinned = false }
      
      val l1 = Label.newNoname ()
      val b1 = mkBlock (l1, [s1], Transfer.Return (Vector.new0 ()))
      val f1 = mkFunction (Func.newNoname (), l1, [b1])
      val p = Program.T {
          functions = [],
          handlesSignals = false,
          main = f1,
          objectTypes = Vector.new0 (),
          profileInfo = NONE,
          statics = Vector.new0 ()
      }
      val vars = TraceHeapOps.collectForbiddenTupleVars p
      val _ = assert (TraceHeapOps.VarSet.size vars = 1, "Should have 1 forbidden var")
      val _ = assert (TraceHeapOps.VarSet.contains (vars, #1 v2), "v2 should be forbidden")
   in () end

   val _ = print "TraceHeapOps.collectForbiddenTupleVars tests finished.\n"

   val _ = print "Running TraceHeapOps.VarSet tests...\n"

   val _ = let
      val _ = print "Test 1: VarSet basic operations\n"
      val v1 = newVar ()
      val v2 = newVar ()
      val v3 = newVar ()
      
      val vs = TraceHeapOps.VarSet.empty
      val _ = assert (TraceHeapOps.VarSet.isEmpty vs, "New set should be empty")
      val _ = assert (TraceHeapOps.VarSet.size vs = 0, "New set size should be 0")
      
      val vs = TraceHeapOps.VarSet.add (vs, #1 v1)
      val _ = assert (not (TraceHeapOps.VarSet.isEmpty vs), "Set should not be empty after add")
      val _ = assert (TraceHeapOps.VarSet.size vs = 1, "Set size should be 1")
      val _ = assert (TraceHeapOps.VarSet.contains (vs, #1 v1), "Set should contain v1")
      val _ = assert (not (TraceHeapOps.VarSet.contains (vs, #1 v2)), "Set should not contain v2")
      
      val vs = TraceHeapOps.VarSet.add (vs, #1 v2)
      val _ = assert (TraceHeapOps.VarSet.size vs = 2, "Set size should be 2")
      val _ = assert (TraceHeapOps.VarSet.contains (vs, #1 v2), "Set should contain v2")
      
      val vs = TraceHeapOps.VarSet.remove (vs, #1 v1)
      val _ = assert (TraceHeapOps.VarSet.size vs = 1, "Set size should be 1 after remove")
      val _ = assert (not (TraceHeapOps.VarSet.contains (vs, #1 v1)), "Set should not contain v1 after remove")
      val _ = assert (TraceHeapOps.VarSet.contains (vs, #1 v2), "Set should still contain v2")
   in () end

   val _ = print "TraceHeapOps.VarSet tests finished.\n"
in
end
