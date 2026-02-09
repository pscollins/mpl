functor EmitDiagnostics (S: EMIT_DIAGNOSTICS_STRUCTS): EMIT_DIAGNOSTICS =
struct

open S
open Machine

fun mapStatements (program: Program.t, rewrite: Statement.t -> Statement.t option):
    Program.t = program

fun emitDiagnostics p = p

end
