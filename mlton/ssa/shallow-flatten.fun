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

fun getBlockCallees (b: Block.t): Label.t vector = let
   fun getLabel (_, l) = l
   fun extractCases (c: (Con.t, Label.t) Cases.t): Label.t vector =
       case c of
           Cases.Con cons => Vector.map (cons, getLabel)
         | Cases.Word (_, cons) => Vector.map (cons, getLabel)
   fun extractDefault d =
       case d of
           SOME d' => Vector.new1 d'
         | NONE => Vector.new0()
in
   case Block.transfer b of
       Transfer.Goto {dst, ...} => Vector.new1 dst
     | Transfer.Case {cases, default, ...} =>
       Vector.concat [extractCases cases,
                      extractDefault default]
     (* `Call`/`Return` are handled by the inter-function traversal: here, we
     only care about intra-function jumps *)
     | _ => Vector.new0()
end

fun rewriteBfs (r: rewriter) (p: Program.t): Program.t = let
   val {doStatements, doArgs, doTransfer} = r
   val Program.T {datatypes, functions, globals, main} = p
   val {getFunc, getBlock, destroyFuncsMap, getCallees} = newFuncsMap p
   fun getLabelCallees l = getBlockCallees (getBlock l)
   fun rewriteBlock l = let
      val Block.T {args, label, statements, transfer} = getBlock l
   in
      (* Order is important *)
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
         getChildren = getLabelCallees,
         rewriteElement = rewriteBlock
      }
   in
      applyRewrite (start, allVec, blockBfsArg)
   end
   fun rewriteFuncs () = let
      fun doRewriteFunc fName = let
         val {args, blocks, inline, name, raises, returns, start} =
             Function.dest (getFunc fName)
         val newArgs = doArgs args
         (* TODO: avoid list->vector *)
         val newBlocks = rewriteBlocks (start, Vector.toList blocks)
      in
         (* Order is important *)
         Function.new {args = doArgs args,
                       blocks = (Vector.fromList o rewriteBlocks) (start, Vector.toList blocks),
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

type visitor = {
   foreachStatements: Statement.t vector -> unit,
   foreachArgs: (Var.t * Type.t) vector -> unit,
   foreachTransfer: Transfer.t -> unit
}

fun foreachBfs (v: visitor) (p: Program.t): unit = let
   val {foreachStatements, foreachArgs, foreachTransfer} = v
   fun ignore f x = (f x; x)
   val r: rewriter = {
      doStatements = ignore foreachStatements,
      doArgs = ignore foreachArgs,
      doTransfer = ignore foreachTransfer
   }
   val _ = rewriteBfs r p
in
   ()
end

fun maybeFlattenType (t: Type.t) = let
   fun maybeFlattenArr xs =
       case Type.dest xs of
           Type.Tuple xs => SOME (Type.tuple (Vector.map (xs, Type.array)))
        |  _ => NONE
in
   case Type.dest t of
       Type.Array arr => maybeFlattenArr arr
    | _ => NONE
end

type flattenedVars = {
   getFlattenedProp: Var.t -> bool,
   setFlattenedProp: Var.t * bool -> unit,
   destroyFlattenedProp: unit -> unit
}
fun newFlattenedVars () = let
   val {get, set, destroy} =
       Property.destGetSetOnce (Var.plist, Property.initConst false)
in
   {getFlattenedProp=get,
    setFlattenedProp=set,
    destroyFlattenedProp=destroy}
end
   
fun destroyFlattenedVars (fv: flattenedVars): unit = let
   val {destroyFlattenedProp, ...} = fv
in
   destroyFlattenedProp()
end

fun markForFlatten (fv: flattenedVars, v: Var.t): unit = let
   val {setFlattenedProp, ...} = fv
in
   setFlattenedProp (v, true)
end

fun isMarkedForFlatten (fv: flattenedVars, v: Var.t): bool = let
   val {getFlattenedProp, ...} = fv
in
   getFlattenedProp v
end

exception BadFlattenError
fun maybeFlattenArg (fv, (v, t)) = let
   val maybeFlat =
       case (isMarkedForFlatten (fv, v), maybeFlattenType t) of
           (true, SOME t') => t'
        |  (false, _) => t
        | _ => raise BadFlattenError
in
   (v, maybeFlat)
end

(* Given the `targs` of an array, returns the corresponding flattened type *)
fun getFlattenedArrayTArg targs =
       if Vector.length targs = 1 then
          (* Wrap in `array` to get the array type:
             Array_alloc['a * b'] ->
             ('a * 'b) array
           *)
          maybeFlattenType (Type.array (Vector.first targs))
       else NONE

(* Returns the unique variable bound by `s`, else crash *)
fun extractBind (s: Statement.t): Var.t =
    case Statement.var s of
        SOME v => v
      | _ => Error.bug ("No bind in statement: " ^
                        Layout.toString (Statement.layout s))

fun maybeFlattenStatement (s: Statement.t) = let
   val Statement.T {exp, ty, var} = s
   fun doPrimApp (args, prim, targs) = let
      fun logThunk () =
          Layout.align [
             Layout.seq [Layout.str "doPrimApp: ",
                         Prim.layout prim,
                         Layout.str " with targs ",
                         Vector.layout Type.layout targs],
             Layout.seq [
                Layout.str "whole_statement: ",
                Statement.layout s]
          ]
      val _ = Control.diagnostic logThunk
      fun mkAlloc targ =  let
         val allocExp = Exp.PrimApp {args=args,
                                     prim=Prim.Array_alloc {raw = false},
                                     targs=Vector.new1 targ}
      in
         Statement.T {exp=allocExp,
                      ty = Type.array targ,
                      var = SOME (Var.newString "flatBind")}
      end
      fun buildArrayAlloc flatArg = let
         val components = Type.deTuple flatArg
         (*
            arr_a = Array_Alloc['a]
            arr_b = Array_Alloc['b]
            ...
         *)
         val newAllocs = Vector.map (components, mkAlloc)
         (* arr = tuple (arr_a, arr_b, ...) *)
         val newTuple = Statement.T {
                exp=Exp.Tuple (Vector.map (newAllocs, extractBind)),
                ty=flatArg,
                var=var
             }
         val _ = print ("num allocs: " ^ ((Int.toString o Vector.length) newAllocs))
         val res = Vector.concat [newAllocs, Vector.new1 newTuple]
         val _ = print ("num total: " ^ ((Int.toString o Vector.length) res))
      in
         (*
           arr_a = ...
           arr_b = ...
           ...
           arr = tuple (...)
         *)
         (* Vector.concat [newAllocs, Vector.new1 newTuple] *)
         res
      end
   in
      case (prim, getFlattenedArrayTArg targs)  of
          (* TODO: handle raw == true *)
          (Prim.Array_alloc {raw=false}, SOME flatArg) =>
          SOME (buildArrayAlloc flatArg)
        | _ => NONE
   end
in
   case exp of
       Exp.PrimApp {args, prim, targs} => doPrimApp (args, prim, targs)
    | _ => NONE
end

fun mustFlattenStatement (fv: flattenedVars, s: Statement.t): bool = let
   val vars = ref []
   fun push x = List.push (vars, x)
   val _ =
       case Statement.var s of
           SOME x => push x
         | _ => ()
   val _ = Exp.foreachVar (Statement.exp s, push)
   fun isFlattened x = isMarkedForFlatten (fv, x)
in
   List.exists (!vars, isFlattened)
end

fun transform (p: Program.t): Program.t = p
end
