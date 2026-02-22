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
in
end
