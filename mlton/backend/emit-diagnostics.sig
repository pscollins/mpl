signature EMIT_DIAGNOSTICS_STRUCTS =
   sig
      structure Machine: MACHINE
   end

signature EMIT_DIAGNOSTICS =
   sig
      include EMIT_DIAGNOSTICS_STRUCTS

      (* Exposed for testing: given a `Machine.Program.t` and a partial
      transformation on `Machine.Statement.t`s, applies the transformation to
      each `Statement.t` in the `Program.t` and, for any applications that return
      SOME, replaces the existing `Statement.t`. *)
      val mapStatements: (Machine.Program.t *
                          (Machine.Statement.t -> Machine.Statement.t option)) ->
                         Machine.Program.t

      val emitDiagnostics: Machine.Program.t -> Machine.Program.t
   end
