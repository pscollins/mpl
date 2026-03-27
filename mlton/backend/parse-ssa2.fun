(* Copyright (C) 2026 Patrick.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor ParseSsa2 (S: SSA_TREE2): PARSE_SSA2 =
struct
   structure Ssa = S
   fun parseString (s: string): Ssa.Program.t =
      case Parse.parseString (Ssa.Program.parse (), s) of
         Parse.Yes p => p
       | Parse.No (layout, loc) =>
            Error.bug (concat ["parse error at ", Int.toString (#line loc),
                               ":", Int.toString (#column loc), "\n",
                               Layout.toString layout])
end
