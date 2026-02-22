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

   val _ = print "Running TraceHeapOps.isForbiddenHeapOp tests...\n"

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
      
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s1), "Move should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s2), "Profile should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s3), "SetExnStackLocal should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s4), "Bind should not be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s5), "SetSlotExnStack should not be forbidden")
   in () end

   (* Test 2: Non-Trace_noHeap PrimApps should return false *)
   val _ = let
      val _ = print "Test 2: Non-Trace_noHeap PrimApps\n"
      val v1 = newVar ()
      val v2 = newVar ()
      
      val s1 = primAdd (v1, v2, v2)
      
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s1), "Word_add should not be forbidden")
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

      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s1), "Trace_noHeap with Var should NOT be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s2), "Trace_noHeap with Const should NOT be forbidden")
      val _ = assert (not (TraceHeapOps.isForbiddenHeapOp s3), "Trace_noHeap with Cast should NOT be forbidden")
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

      val _ = assert (TraceHeapOps.isForbiddenHeapOp s1, "Trace_noHeap with Offset SHOULD be forbidden")
      val _ = assert (TraceHeapOps.isForbiddenHeapOp s2, "Trace_noHeap with GCState SHOULD be forbidden")
      val _ = assert (TraceHeapOps.isForbiddenHeapOp s3, "Trace_noHeap with SequenceOffset SHOULD be forbidden")
   in () end

   val _ = print "TraceHeapOps.isForbiddenHeapOp tests finished.\n"
in
end
