signature PARSE_SSA2 =
   sig
      structure Ssa: SSA_TREE2
      (* P *)
      val parseString: string -> Ssa.Program.t
   end
