signature EMIT_DIAGNOSTICS_STRUCTS =
   sig
      structure Machine: MACHINE
   end

signature EMIT_DIAGNOSTICS =
   sig
      include EMIT_DIAGNOSTICS_STRUCTS

      val emitDiagnostics: Machine.Program.t -> Machine.Program.t
   end
