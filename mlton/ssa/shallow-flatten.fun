functor ShallowFlatten (S: SSA_TRANSFORM_STRUCTS): SHALLOW_FLATTEN =
struct
open S
structure FlattenUtil = FlattenUtil (S)
open FlattenUtil

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
   val {getFunc, destroyFuncsMap, getCallees, ...} = newFuncsMap p
   fun rewriteFuncs () = let
      val {popRemaining, ...} = mkQueue [functions]
      val {pushFunc, popFunc} = mkQueue [main]
      val {markVisited, destroyVisited} = mkVisited Func.plist
      val {getRewrittenFunc, setRewrittenFunc, destroyRewrittenFunc} =
          Property.destGetSetOnce (Func.plist, Property.initRaise ("result lookup",
                                                                   Func.layout))
      fun getNext() =
          case popFunc() of
              NONE => pushLeftovers()
            | x => x
      and pushLeftovers() =
          case popRemaining of
              NONE => NONE
            | SOME f => (pushFunc f; getNext())

      fun visitFunc f = let
         (* Add callees to the queue *)
         val _ = Vector.foreach (getCallees f, pushFunc)
         val {args, blocks, inline, name, raises, returns, starts} =
             Function.dest f
      in
         Function.new {doArgs args,
                       (* TODO: rewrite blocks *)
                       blocks,
                       inline,
                       name,
                       raises,
                       returns,
                       starts}
      end
      fun maybeVisit f =
          if markVisited f then ()
          else (setRewrittenFunc (f, visitFunc f))

      fun doVisit () =
          case getNext() of
              NONE => ()
            | SOME f => (maybeVisit f; doVisit())
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
