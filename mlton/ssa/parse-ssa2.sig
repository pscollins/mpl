signature PARSE_SSA2 =
   sig
      structure Ssa2: SSA_TREE2

      (* Pases the provided string into an `Ssa2.Program.t`; raises an error on
      failure*)
      val parseString: string -> Ssa2.Program.t
   end
