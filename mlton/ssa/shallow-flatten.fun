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

type ('a, 'label) bfsArg = {
   getLabel: 'a -> 'label,
   getPlist: 'label -> PropertyList.t,
   labelLayout: 'label -> Layout.t,
   getChildren: 'label -> 'label vector,
   rewriteElement: 'label -> 'a
}

fun applyRewrite (init: 'label, all: 'a list, arg: ('a, 'label) bfsArg): 'a list = let
   val {getLabel, getPlist, labelLayout, getChildren,
        rewriteElement} = arg
   val allLabels = List.map (all, getLabel)
   val {pop=popRemaining, ...} : 'label mutableQueue
       = mkQueue allLabels
   val {push=pushFunc, pop=popFunc} : 'label mutableQueue
       = mkQueue [init]
   val {markVisited, destroyVisited} = mkVisited getPlist
   val {get=getRewrittenFunc: 'label -> 'a,
        set=setRewrittenFunc: 'label * 'a -> unit,
        destroy=destroyRewrittenFunc} =
       Property.destGetSetOnce (getPlist, Property.initRaise ("result lookup",
                                                              labelLayout))
   fun getNext(): 'label option =
       case popFunc() of
           NONE => pushLeftovers()
         | x => x
   and pushLeftovers(): 'label option =
       case (popRemaining(): 'label option) of
           NONE => NONE
         | SOME f  => (pushFunc f; getNext())

   fun visitFunc f = let
      (* Add callees to the queue *)
      val _ = Vector.foreach (getChildren f, pushFunc)
   in
      rewriteElement f
   end
   fun maybeVisit f =
       if markVisited f then ()
       else (setRewrittenFunc (f, visitFunc f))

   fun doVisit () =
       case getNext() of
           NONE => ()
         | SOME f => (maybeVisit f; doVisit())

   val _ = doVisit ()
   val results = List.map (allLabels, getRewrittenFunc)
   val _ = (destroyVisited();
            destroyRewrittenFunc())
in
   results
end

fun getBlockCallees b = Error.unimplemented "TODO"

fun rewriteBfs (r: rewriter) (p: Program.t): Program.t = let
   val {doStatements, doArgs, doTransfer} = r
   val Program.T {datatypes, functions, globals, main} = p
   val {getFunc, getBlock, destroyFuncsMap, getCallees} = newFuncsMap p
   fun getLabelCallees l = getBlockCallees (getBlock l)
   fun rewriteBlock l = let
      val Block.T {args, label, statements, transfer} = getBlock l
   in
      Block.T {args = doArgs args,
               label = label,
               statements = doStatements statements,
               transfer = doTransfer transfer}
   end
   fun rewriteBlocks (start, allVec) = let
      val blockBfsArg: (Block.t, Label.t) bfsArg = {
         getLabel = Block.label,
         getPlist = Label.plist,
         labelLayout = Label.layout,
         getChildren = getBlockCallees,
         rewriteElement = rewriteBlock
      }
   in
      applyRewrite (start, allVec, blockBfsArg)
   end
   fun rewriteFuncs () = let
      fun doRewriteFunc fName = let
         val {args, blocks, inline, name, raises, returns, start} =
             Function.dest (getFunc fName)
         (* TODO: avoid list->vector *)
         val newBlocks = rewriteBlocks (start, Vector.toList blocks)
      in
         Function.new {args = doArgs args,
                       (* TODO: rewrite blocks *)
                       blocks = Vector.fromList newBlocks,
                       inline = inline,
                       name = name,
                       raises = raises,
                       returns = returns,
                       start = start}
      end
      val funcBfs: (Function.t, Func.t) bfsArg = {
         getLabel = Function.name,
         getPlist = Func.plist,
         labelLayout = Func.layout,
         getChildren = getCallees,
         rewriteElement = doRewriteFunc
      }
   in
      applyRewrite (main, functions,
                    funcBfs)
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
