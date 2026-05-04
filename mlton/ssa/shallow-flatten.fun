functor ShallowFlatten (S: SSA_TRANSFORM_STRUCTS): SHALLOW_FLATTEN =
struct
open S

type rewriter = {
   doStatements: Statement.t vector -> Statement.t vector,
   doArgs: (Var.t * Type.t) vector -> (Var.t * Type.t) vector,
   doTransfer: Transfer.t -> Transfer.t
}

type 'a visited = {
   (* Marks the object as visited and returns whether or not it was previously
   marked *)
   markVisited: 'a -> bool,
   destroyVisited: unit -> unit
}

fun mkVisited plist = let
   fun init _ = ref false
   val {get=getVisited, dest=destroyVisited, ...} =
       Property.destGet (plist, Property.initFun init)
   fun markVisited p = let 
      val seenRef = getVisited p
      val wasSeen = !seenRef
      val _ = seenRef := true
   in 
      wasSeen
   end
in
   {markVisited = markVisited,
    destroyVisited = destroyVisited}
end

type 'a mutableQueue = {
   push: 'a -> unit,
   pop: unit -> 'a option
}
fun mkQueue inits = let
   val q = ref Queue.empty
   fun push f = q := Queue.enqueue (!q, f)
   fun pop () =
       case Queue.deque (!q) of
           SOME (q', el) => (q := q'; SOME el)
         | NONE => NONE
   val = List.foreach (inits, push)
in
   {push = push, pop = pop}
end

fun rewriteBfs (r: rewriter) (p: Program.t): Program.t = let
   val {doStatements, doArgs, doTransfer} = r
   val Program.T {datatypes, functions, globals, main} = p
   (* TODO(gemini): refactor out of pre-flatten.fun into flatten-util.fun *)
   val {getFunc, getBlock, destroyFuncsMap} = newFuncsMap p
   fun rewriteFuncs () = let
      val {popRemaining, ...} = mkQueue [functions]
      val {pushFunc, popFunc} = mkQueue [main]
      val {markVisited, destroyVisited} = mkVisited Func.plist
      fun visitFunc f = let
         if markVisited f then ()
         else getCallees f
      and visit () = let
         fun visitF = 
          case popFunc of 
   in

   end

   val _ = Error.unimplemented "TODO"
in
   Program.T {datatypes = datatypes,
              functions = rewriteFuncs(),
              globals = doStatements globals,
              main = main}
end

fun transform (p: Program.t): Program.t = p
end
