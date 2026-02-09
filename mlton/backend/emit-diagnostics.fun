functor EmitDiagnostics (S: EMIT_DIAGNOSTICS_STRUCTS): EMIT_DIAGNOSTICS =
struct

open S
open Machine

fun mapStatements (program: Program.t, rewrite: Statement.t -> Statement.t option):
    Program.t = let
   fun doStatement (s: Statement.t): Statement.t =
       case rewrite s of
          SOME s'  => s'
        | NONE => s
   fun doBlock (Block.T {kind, label, live, raises, returns, statements,
                         transfer}): Block.t =
       Block.T {kind = kind, label = label, live = live,
                raises = raises, returns = returns,
                statements = Vector.map (statements, doStatement),
                transfer = transfer}
   fun doChunk (Chunk.T {blocks, chunkLabel, tempsMax}): Chunk.t =
       Chunk.T {blocks = Vector.map (blocks, doBlock),
                chunkLabel = chunkLabel,
                tempsMax = tempsMax}
   val Program.T {chunks, frameInfos, frameOffsets, globals,
                  handlesSignals, main, maxFrameSize, objectTypes,
                  sporkInfos, sourceMaps, staticHeaps} = program
in
   Program.T {chunks = List.map (chunks, doChunk),
              frameInfos = frameInfos,
              frameOffsets = frameOffsets,
              globals = globals,
              handlesSignals = handlesSignals,
              main = main,
              maxFrameSize = maxFrameSize,
              objectTypes = objectTypes,
              sporkInfos = sporkInfos,
              sourceMaps = sourceMaps,
              staticHeaps = staticHeaps}
end

fun emitDiagnostics p = p

end
