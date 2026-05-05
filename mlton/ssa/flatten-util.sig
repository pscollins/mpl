signature FLATTEN_UTIL =
sig
   include SSA_TRANSFORM_STRUCTS

   (* Applies an effectful expression to each `Function.t` in `p` *)
   val foreachFunction: Program.t * (Function.t -> unit) -> unit

   (* Manages Func.t -> Function + Label.t -> Block mappings *)
   type funcsMap = {
      getFunc: Func.t -> Function.t,
      getBlock: Label.t -> Block.t,
      destroyFuncsMap: unit -> unit
   }

   val newFuncsMap: Program.t -> funcsMap
end
