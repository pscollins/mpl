signature EXTRACT_SSA_SUBGRAPH_STRUCTS =
sig
   include SSA_TRANSFORM_STRUCTS
end

signature EXTRACT_SSA_SUBGRAPH =
sig
   include EXTRACT_SSA_SUBGRAPH_STRUCTS

   (* Extracts the minimal program subgraph containing the `Var.t`

      Executes the following steps:

        1. Locate the `Statement.t` (call it `s`) that defines the provided
           `Var.t`: if no such statement exists, raises Fail, else mark `s`.

        2. Traverse the data dependency graph upwards to mark, transitively,
           every `Statement.t` that is connected to `s`

        3. Likewise, traverse the data dependency graph downwards to mark,
           transitively, every `Statement.t` that is connected to `s`.

        4. Filter the input `Program.t` to contain only marked `Statement.t`s
           plus `Datatype.t`s that appear in a marked `Statement.t`. Any
           `Function.t`s that become empty as a result are dropped, except for a
           dummy function pointed to by the `main` attribute of the specified
           `Program.t`. Empty `BasicBlock.t`s are also deleted (except when a
           dummy block is required to make the program well-formed). Any
           `Transfer.t`s to a filtered-out target are replaced by `Transfer.Bug`

      Data dependencies are traversed within functions and across functions, i.e. for:

       fun f(a: int, b: int):
         x = a + b
         y = x + 1
         return g(y)

       fun g(c: int):
         z = c * c
         return z

       fun h():
         w = g(2) + 1
         return w

      The "upwards dependencies" of `z` are the statements:
        x = a + b
        y = x + 1
        return g(y)


      and the "downwards dependencies" are the statements:
        return z
        w = g(2) + 1
        return w
   *)
   val isolateSubgraph: (Program.t * Var.t) -> Program.t

   (* Dummy, unimplemented function *)
   val transform: Program.t -> Program.t
end
