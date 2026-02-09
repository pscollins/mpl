structure Atoms = Atoms ()
structure BackendAtoms = BackendAtoms (open Atoms)
structure Machine = Machine (open BackendAtoms)
structure EmitDiagnostics = EmitDiagnostics (structure Machine = Machine)

local
   open Machine
in
   val p = Program.T {
       chunks = [],
       frameInfos = Vector.new0 (),
       frameOffsets = Vector.new0 (),
       globals = {objptrs = [], reals = []},
       handlesSignals = false,
       main = {chunkLabel = ChunkLabel.newNoname (),
               label = Label.newNoname ()},
       maxFrameSize = Bytes.zero,
       objectTypes = Vector.new0 (),
       sporkInfos = Vector.new0 (),
       sourceMaps = NONE,
       staticHeaps = fn _ => Vector.new0 ()
   }

   val _ = EmitDiagnostics.emitDiagnostics p
   val _ = print "EmitDiagnostics test passed.\n"
end