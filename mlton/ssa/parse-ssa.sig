signature PARSE_SSA =
   sig
      structure Ssa: SSA_TREE

      (* Pases the provided string into an `Ssa.Program.t`; raises an error on
      failure*)
      val parseString: string -> Ssa.Program.t
   end
