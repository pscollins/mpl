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
   val {get=getVisited, destroy=destroyVisited, ...} =
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
   val q = ref (Queue.empty())
   fun push f = q := Queue.enque (!q, f)
   fun pop () =
       case Queue.deque (!q) of
           SOME (q', el) => (q := q'; SOME el)
         | NONE => NONE
   val _ = List.foreach (inits, push)
in
   {push = push, pop = pop}
end

fun rewriteBfs (r: rewriter) (p: Program.t): Program.t = let
   val {doStatements, doArgs, doTransfer} = r
   val Program.T {datatypes, functions, globals, main} = p
   val {getFunc, destroyFuncsMap, getCallees, ...} = newFuncsMap p
   fun rewriteFuncs () = let
      val funcs = List.map (functions, Function.name)
      val {pop=popRemaining, ...} : Func.t mutableQueue
          = mkQueue funcs
      val {push=pushFunc, pop=popFunc} : Func.t mutableQueue
          = mkQueue [main]
      val {markVisited, destroyVisited} = mkVisited Func.plist
      val {get=getRewrittenFunc,
           set=setRewrittenFunc,
           destroy=destroyRewrittenFunc} =
          Property.destGetSetOnce (Func.plist, Property.initRaise ("result lookup",
                                                                   Func.layout))
      fun getNext(): Func.t option =
          case popFunc() of
              NONE => pushLeftovers()
            | x => x
      and pushLeftovers() =
          case (popRemaining(): Func.t option) of
              NONE => NONE
            | SOME (f: Func.t) => (pushFunc f; getNext())

      fun visitFunc f = let
         (* Add callees to the queue *)
         val _ = Vector.foreach (getCallees f, pushFunc)
         val {args, blocks, inline, name, raises, returns, start} =
             Function.dest (getFunc f)
      in
         Function.new {args = doArgs args,
                       (* TODO: rewrite blocks *)
                       blocks = blocks,
                       inline = inline,
                       name = name,
                       raises = raises,
                       returns = returns,
                       start = start}
      end
      fun maybeVisit f =
          if markVisited f then ()
          else (setRewrittenFunc (f, visitFunc f))

      fun doVisit () =
          case getNext() of
              NONE => ()
            | SOME f => (maybeVisit f; doVisit())

      val _ = doVisit ()
      val results = List.map (funcs, getRewrittenFunc)
      val _ = (destroyVisited();
               destroyRewrittenFunc())
   in
      results
   end

in
   Program.T {datatypes = datatypes,
              (* Order is important *)
              globals = doStatements globals,
              functions = rewriteFuncs(),
              main = main}
end

fun transform (p: Program.t): Program.t = p
end
