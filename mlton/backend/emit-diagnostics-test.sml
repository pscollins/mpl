structure Atoms = Atoms ()
structure BackendAtoms = BackendAtoms (open Atoms)
structure Machine = Machine (open BackendAtoms)
structure EmitDiagnostics = EmitDiagnostics (structure Machine = Machine)

local
   open Machine

   fun hasDiagnostic (Program.T {chunks, ...}, msg) =
      List.exists (chunks, fn Chunk.T {blocks, ...} =>
         Vector.exists (blocks, fn Block.T {statements, ...} =>
            Vector.exists (statements, fn s =>
               case s of
                  Statement.Diagnostic m => m = msg
                | _ => false
            )
         )
      )

   fun assert (cond, msg) =
      if cond then () else (print ("Assertion failed: " ^ msg ^ "\n"); raise Fail msg)

   val label = Label.newNoname ()
   val chunkLabel = ChunkLabel.newNoname ()
   
   val b1 = Block.T {
       kind = Kind.Jump,
       label = label,
       live = Vector.new0 (),
       raises = NONE,
       returns = NONE,
       statements = Vector.fromList [Statement.Diagnostic "original"],
       transfer = Transfer.Goto label
   }

   val c1 = Chunk.T {
       blocks = Vector.fromList [b1],
       chunkLabel = chunkLabel,
       tempsMax = fn _ => 0
   }

   val p1 = Program.T {
       chunks = [c1],
       frameInfos = Vector.new0 (),
       frameOffsets = Vector.new0 (),
       globals = {objptrs = [], reals = []},
       handlesSignals = false,
       main = {chunkLabel = chunkLabel,
               label = label},
       maxFrameSize = Bytes.zero,
       objectTypes = Vector.new0 (),
       sporkInfos = Vector.new0 (),
       sourceMaps = NONE,
       staticHeaps = fn _ => Vector.new0 ()
   }

   val _ = print "Running mapStatements test 1...\n"
   val p1' = EmitDiagnostics.mapStatements (p1, fn s =>
      case s of
         Statement.Diagnostic "original" => SOME (Statement.Diagnostic "transformed")
       | _ => NONE)

   val _ = assert (hasDiagnostic (p1', "transformed"), "Test 1: 'transformed' diagnostic not found")
   val _ = assert (not (hasDiagnostic (p1', "original")), "Test 1: 'original' diagnostic still found")

   (* Test 2: multiple statements in one block *)
   val b2 = Block.T {
       kind = Kind.Jump,
       label = Label.newNoname (),
       live = Vector.new0 (),
       raises = NONE,
       returns = NONE,
       statements = Vector.fromList [Statement.Diagnostic "a", 
                                     Statement.Diagnostic "b",
                                     Statement.Diagnostic "c"],
       transfer = Transfer.Goto label
   }
   val c2 = Chunk.T {
       blocks = Vector.fromList [b2],
       chunkLabel = ChunkLabel.newNoname (),
       tempsMax = fn _ => 0
   }
   val p2 = Program.T {
       chunks = [c2],
       frameInfos = Vector.new0 (),
       frameOffsets = Vector.new0 (),
       globals = {objptrs = [], reals = []},
       handlesSignals = false,
       main = {chunkLabel = chunkLabel,
               label = label},
       maxFrameSize = Bytes.zero,
       objectTypes = Vector.new0 (),
       sporkInfos = Vector.new0 (),
       sourceMaps = NONE,
       staticHeaps = fn _ => Vector.new0 ()
   }

   val _ = print "Running mapStatements test 2...\n"
   val p2' = EmitDiagnostics.mapStatements (p2, fn s =>
      case s of
         Statement.Diagnostic "a" => SOME (Statement.Diagnostic "A")
       | Statement.Diagnostic "c" => SOME (Statement.Diagnostic "C")
       | _ => NONE)

   val _ = assert (hasDiagnostic (p2', "A"), "Test 2: 'A' not found")
   val _ = assert (hasDiagnostic (p2', "b"), "Test 2: 'b' not found")
   val _ = assert (hasDiagnostic (p2', "C"), "Test 2: 'C' not found")
   val _ = assert (not (hasDiagnostic (p2', "a")), "Test 2: 'a' still found")
   val _ = assert (not (hasDiagnostic (p2', "c")), "Test 2: 'c' still found")

   (* Test 3: multiple chunks and blocks *)
   val b3a = Block.T {
       kind = Kind.Jump,
       label = Label.newNoname (),
       live = Vector.new0 (),
       raises = NONE,
       returns = NONE,
       statements = Vector.fromList [Statement.Diagnostic "3a"],
       transfer = Transfer.Goto label
   }
   val b3b = Block.T {
       kind = Kind.Jump,
       label = Label.newNoname (),
       live = Vector.new0 (),
       raises = NONE,
       returns = NONE,
       statements = Vector.fromList [Statement.Diagnostic "3b"],
       transfer = Transfer.Goto label
   }
   val c3a = Chunk.T {
       blocks = Vector.fromList [b3a],
       chunkLabel = ChunkLabel.newNoname (),
       tempsMax = fn _ => 0
   }
   val c3b = Chunk.T {
       blocks = Vector.fromList [b3b],
       chunkLabel = ChunkLabel.newNoname (),
       tempsMax = fn _ => 0
   }
   val p3 = Program.T {
       chunks = [c3a, c3b],
       frameInfos = Vector.new0 (),
       frameOffsets = Vector.new0 (),
       globals = {objptrs = [], reals = []},
       handlesSignals = false,
       main = {chunkLabel = chunkLabel,
               label = label},
       maxFrameSize = Bytes.zero,
       objectTypes = Vector.new0 (),
       sporkInfos = Vector.new0 (),
       sourceMaps = NONE,
       staticHeaps = fn _ => Vector.new0 ()
   }

   val _ = print "Running mapStatements test 3...\n"
   val p3' = EmitDiagnostics.mapStatements (p3, fn s =>
      case s of
         Statement.Diagnostic "3a" => SOME (Statement.Diagnostic "3A")
       | Statement.Diagnostic "3b" => SOME (Statement.Diagnostic "3B")
       | _ => NONE)

   val _ = assert (hasDiagnostic (p3', "3A"), "Test 3: '3A' not found")
   val _ = assert (hasDiagnostic (p3', "3B"), "Test 3: '3B' not found")
   val _ = assert (not (hasDiagnostic (p3', "3a")), "Test 3: '3a' still found")
   val _ = assert (not (hasDiagnostic (p3', "3b")), "Test 3: '3b' still found")

   val _ = print "EmitDiagnostics tests passed.\n"
in
end
