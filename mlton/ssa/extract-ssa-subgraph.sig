signature EXTRACT_SSA_SUBGRAPH_STRUCTS =
sig
   include SSA_TRANSFORM_STRUCTS
end

signature EXTRACT_SSA_SUBGRAPH =
sig
   include EXTRACT_SSA_SUBGRAPH_STRUCTS

   (* Extracts the minimal program subgraph containing the `Var.t`

      Executes the following steps:

        1. Locate the definition of the provided `Var.t` (which may be a
           `Statement.t` or a block/function argument). Mark it.

        2. Traverse the directed data dependency graph upwards to mark,
           transitively, every statement and argument that is an upward
           dependency.

        3. Likewise, traverse the directed data dependency graph downwards
           to mark, transitively, every statement and argument that is a
           downward dependency.

        4. Filter the input `Program.t` to keep only blocks and functions
           containing at least one marked statement or argument. The `main`
           function and start blocks of kept functions are always preserved.
           Unused statements and block/function arguments are filtered out,
           and arguments in call/goto transfers are updated accordingly.
           Any `Transfer.t` targeting a deleted block or function is
           replaced by `Transfer.Bug`. Datatypes are filtered to keep only
           those whose `Tycon.t` appears in a preserved statement/argument.

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

      The "upwards dependencies" of `z` are the statements/arguments:
        x = a + b
        y = x + 1
        return g(y) (call site)
        c (parameter of g)
        a and b (parameters of f)

      and the "downwards dependencies" are the statements/arguments:
        return z
        w = g(2) + 1 (representing call return)
        return w
   *)
   val isolateSubgraph: (Program.t * Var.t) -> Program.t

   (* Dummy, unimplemented function *)
   val transform: Program.t -> Program.t
end
