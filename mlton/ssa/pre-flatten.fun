functor PreFlatten (S: SSA_TRANSFORM_STRUCTS): SSA_TRANSFORM =
struct
   open S

   fun transform (p: Program.t): Program.t =
      p
end
