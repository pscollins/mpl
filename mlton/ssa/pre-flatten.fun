functor PreFlatten (S: SSA_TRANSFORM_STRUCTS): PRE_FLATTEN =
struct
open S

type walker = {
   (* Hook to execute before visiting a function body *)
   beforeFunc: Function.t -> unit,
   (* Hook to execute after visiting a function body *)
   afterFunc: Function.t -> unit,
   (* Hook to execute before visiting a block body *)
   beforeBlock: Block.t -> unit,
   (* Hook to execute after visiting a block body *)
   afterBlock: Block.t -> unit,
   (* Hook to execute when visiting a statement *)
   statement: Statement.t -> unit
}

fun doWalk (w: walker, p: Program.t) =
    (* TODO(pscollins): Implement *)
    ()

fun transform (p: Program.t): Program.t =
    p
end
