signature FLATTEN_UTIL =
sig
   include SSA_TRANSFORM_STRUCTS

   (* Applies an effectful expression to each `Function.t` in `p` *)
   val foreachFunction: Program.t * (Function.t -> unit) -> unit

   (* Manages Func.t -> Function + Label.t -> Block mappings *)
   type funcsMap = {
      (* Returns the `Function.t` for each `Func.t` in the program  *)
      getFunc: Func.t -> Function.t,
      (* Returns the `Block.t` corresponding to the provided `Label.t` *)
      getBlock: Label.t -> Block.t,
      (* Given a `Func.t`, returns all of the functions that it calls *)
      getCallees: Func.t -> Func.t vector
      (* Cleans up state associated with this object *)
      destroyFuncsMap: unit -> unit
   }

   (* Builds a new `funcsMap` over the provided program *)
   val newFuncsMap: Program.t -> funcsMap
end
