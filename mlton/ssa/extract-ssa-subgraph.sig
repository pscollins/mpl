signature EXTRACT_SSA_SUBGRAPH_STRUCTS =
   sig
      include SSA_TRANSFORM_STRUCTS
   end

signature EXTRACT_SSA_SUBGRAPH =
   sig
      include EXTRACT_SSA_SUBGRAPH_STRUCTS

      val transform: Program.t -> Program.t
   end
