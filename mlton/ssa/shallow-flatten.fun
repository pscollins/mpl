functor ShallowFlatten (S: SSA_TRANSFORM_STRUCTS): SHALLOW_FLATTEN =
struct
open S
structure FlattenUtil = FlattenUtil (S)
open FlattenUtil

(* Returns the unique variable bound by `s`, else crash *)
fun extractBind (s: Statement.t): Var.t =
    case Statement.var s of
        SOME v => v
      | _ => Error.bug ("No bind in statement: " ^
                        Layout.toString (Statement.layout s))

(* Returns the type of the given statement *)
fun extractType (s: Statement.t): Type.t = let
   val Statement.T {ty, ...} = s
in
   ty
end

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

fun applyRewrite (init: 'label, all: 'a list,
                  arg: ('a, 'label) bfsArg): 'a list = let
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
         val newBlocks = rewriteBlocks (start, Vector.toList blocks)
      in
         (* Order is important *)
         Function.new {args = newArgs,
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
   fun maybeFlattenVec xs =
       case Type.dest xs of
           Type.Tuple xs => SOME (Type.tuple (Vector.map (xs, Type.vector)))
        |  _ => NONE
in
   case Type.dest t of
       Type.Array arr => maybeFlattenArr arr
     | Type.Vector vec => maybeFlattenVec vec
     | _ => NONE
end

fun deContainer (t: Type.t) =
    case Type.dest t of
        Type.Array arr => arr
      | Type.Vector vec => vec
      | _ => Error.bug "Bad deContainer"

(* ('a array * 'b array * ...)
   ->
   {'a, 'b, ...}

  (and likewise for `vector`)
*)
fun getFlattenedElementTypes (flatType: Type.t) =
    Vector.map (Type.deTuple flatType, deContainer)

(* Returns:

    * t == tuple? number of tuple elements
    * t != tuple? 0
*)
fun getTupleTypeWidth (t: Type.t): int =
    case Type.deTupleOpt t of
        SOME ts => Vector.length ts
      | _ => 0

(* Like above, but requires that `t` is `(...) array` or `(...) vector` *)
fun getContainerOfTupleTypeWidth (t: Type.t): int =
    case Type.dest t of
        Type.Array t' => getTupleTypeWidth t'
      | Type.Vector t' => getTupleTypeWidth t'
      | _ => 0

datatype flattenPolicy = MaxWidth of int

(* Should the value corresponding to `t` be marked, according to `policy`? *)
fun shouldMarkType (policy: flattenPolicy, t: Type.t) = let
   val MaxWidth (maxWidth) = policy
   (* No reason to flatten tuples with <2 elements *)
   val kMinWidth = 2
   val currWidth = getContainerOfTupleTypeWidth t
in
   (currWidth >= kMinWidth) andalso (currWidth <= maxWidth)
end

fun getChildren (t: Type.t): Type.t vector =
    case Type.dest t of
        Type.Array t' => Vector.new1 t'
      | Type.Ref t' => Vector.new1 t'
      | Type.Tuple ts' => ts'
      | Type.Vector t' => Vector.new1 t'
      | Type.Weak t' => Vector.new1 t'
      | _ => Vector.new0 ()

datatype conDecision =
         PreserveNode of conDecision vector
         | FlattenNode of conDecision vector

fun layoutConDecision cd =
    case cd of
        PreserveNode cds =>
        Layout.seq [Layout.str "Preserve", Layout.paren (Vector.layout layoutConDecision cds)]
      | FlattenNode cds =>
        Layout.seq [Layout.str "Flatten", Layout.paren (Vector.layout layoutConDecision cds)]

fun getConDecisionForPolicy (policy: flattenPolicy)
                            (t: Type.t): conDecision = let
   fun shouldMark t = shouldMarkType (policy, t)
   val MaxWidth (width) = policy
   fun walk (t: Type.t) = let
      fun next t' = Vector.map (getChildren t', walk)
   in
      if shouldMark t then
         (* Peel off a layer in the recursion for flattening *)
         FlattenNode (next (deContainer t))
      else
         PreserveNode (next t)
   end
in
   walk t
end

fun getUniqueElement (xs: 'a vector): 'a =
    if Vector.length xs = 1 then
       Vector.first xs
    else Error.bug ("Bad length: " ^ Int.toString (Vector.length xs))

exception InvalidConFlattening
fun applyConDecision (cd: conDecision,
                      t: Type.t): Type.t = let
   fun assertEmpty xs =
       if Vector.length xs = 0 then ()
       else raise InvalidConFlattening
   fun walk (t, cd): Type.t =
       case (Type.dest t, cd) of
           (* Single-child, flattenable nodes *)
           (Type.Array t', PreserveNode cd') =>
           Type.array (walk (t', getUniqueElement cd'))
         | (Type.Array t', FlattenNode cds') =>
            Type.tuple (Vector.map2 (Type.deTuple t',
                                     cds',
                                     Type.array o walk))
          | (Type.Vector t', PreserveNode cd') =>
           Type.vector (walk (t', getUniqueElement cd'))
         | (Type.Vector t', FlattenNode cds') =>
           Type.tuple (Vector.map2 (Type.deTuple t',
                                    cds',
                                    Type.vector o walk))         (* Multi-child, un-flattenable internal nodes *)
           | (Type.Tuple ts', PreserveNode cds') =>
             Type.tuple (Vector.map2 (ts', cds', walk))
         (* Single-child, un-flattenable internal nodes *)
         | (Type.Ref t', PreserveNode cd') =>
           Type.reff (walk (t', getUniqueElement cd'))
         | (Type.Weak t', PreserveNode cd') =>
           Type.weak (walk (t', getUniqueElement cd'))
         (* Leaf nodes *)
         | (_, PreserveNode cd') =>
           (assertEmpty cd'; t)
         (* Invalid flattening decisions *)
         | _ => raise InvalidConFlattening

   val _ = ()
in
   walk (t, cd)
end

type flattenedVars = {
   getFlattenedProp: Var.t -> bool,
   setFlattenedProp: Var.t * bool -> unit,
   getFlattenedConProp: Con.t -> conDecision vector,
   setFlattenedConProp: Con.t * conDecision vector -> unit,
   getArgFlatteningProp: Var.t -> conDecision,
   setArgFlatteningProp: Var.t * conDecision -> unit,
   destroyFlattenedProps: unit -> unit,
   count: int ref
}
fun newFlattenedVars () = let
   val {get, set, destroy} =
       Property.destGetSetOnce (Var.plist, Property.initConst false)

   val {get=get', set=set', destroy=destroy'} =
       Property.destGetSetOnce (Con.plist, Property.initRaise
                                               ("flattenCon", Con.layout))

   val {get=get'', set=set'', destroy=destroy''} =
       Property.destGetSetOnce (Var.plist, Property.initRaise
                                               ("flattenArg", Var.layout))
   fun doDestroy() =
       (destroy(); destroy'(); destroy''())
in
   {getFlattenedProp=get,
    setFlattenedProp=set,
    getFlattenedConProp=get',
    setFlattenedConProp=set',
    getArgFlatteningProp=get'',
    setArgFlatteningProp=set'',
    destroyFlattenedProps=doDestroy,
    count=ref 0}
end

fun destroyFlattenedVars (fv: flattenedVars): unit = let
   val {destroyFlattenedProps, ...} = fv
in
   destroyFlattenedProps()
end

fun markForFlatten (fv: flattenedVars, v: Var.t): unit = let
   val {setFlattenedProp, count, ...} = fv
   val _ = count := (!count + 1)
   fun logThunk () =
       Layout.seq [Layout.str "markForFlatten: ",
                   Var.layout v]
   val _ = Control.diagnostic logThunk
in
   setFlattenedProp (v, true)
end

fun setConFlatteningDecision (fv: flattenedVars, c: Con.t,
                       decisions: conDecision vector): unit = let
   val {setFlattenedConProp, count, ...} = fv
   fun logThunk () =
       Layout.seq [Layout.str "setConFlatteningDecision: ",
                   Con.layout c,
                   Layout.str ": ",
                   Vector.layout layoutConDecision decisions]
   val _ = Control.diagnostic logThunk
in
   setFlattenedConProp (c, decisions)
end

fun isMarkedForFlatten (fv: flattenedVars, v: Var.t): bool = let
   val {getFlattenedProp, ...} = fv
in
   getFlattenedProp v
end

fun getConFlatteningDecision (fv: flattenedVars, c: Con.t): conDecision vector = let
   val {getFlattenedConProp, ...} = fv
in
   getFlattenedConProp c
end

fun setArgFlatteningDecision (fv: flattenedVars, v: Var.t,
                              decision: conDecision): unit = let
   val {setArgFlatteningProp, count, ...} = fv
   val _ = count := (!count + 1)
   fun logThunk () =
       Layout.seq [Layout.str "setArgFlatteningDecision: ",
                   Var.layout v,
                   Layout.str ": ",
                   layoutConDecision decision]
   val _ = Control.diagnostic logThunk
in
   setArgFlatteningProp (v, decision)
end

fun getArgFlatteningDecision (fv: flattenedVars, v: Var.t): conDecision = let
   val {getArgFlatteningProp, ...} = fv
in
   getArgFlatteningProp v
end

fun markedCount (fv: flattenedVars): int = let
   val {count, ...} = fv
in
   !count
end

type varTypes = {
   getType: Var.t -> Type.t,
   setType: Var.t * Type.t -> unit,
   getReturnType: Func.t -> Type.t vector option,
   setReturnType: Func.t * Type.t vector option -> unit,
   destroy: unit -> unit
}
fun newVarTypes () = let
   val {get = getType, set = setType, destroy = destroyVar} =
       Property.destGetSet (Var.plist, Property.initRaise ("varType", Var.layout))
   val {get = getReturnType, set = setReturnType, destroy = destroyFunc} =
       Property.destGetSet (Func.plist, Property.initRaise ("returnType", Func.layout))
   fun destroy () =
      (destroyVar ()
       ; destroyFunc ())
in
   {getType = getType,
    setType = setType,
    getReturnType = getReturnType,
    setReturnType = setReturnType,
    destroy = destroy}
end
fun destroyVarTypes (vt: varTypes) = let
   val {destroy, ...} = vt
in
   destroy()
end

fun setVarType (vt: varTypes, v, t) = let
   val {setType, ...} = vt
in
   setType (v, t)
end

fun getVarType (vt: varTypes, v) = let
   val {getType, ...} = vt
in
   getType v
end

fun setReturnType (vt: varTypes, f, t) = let
   val {setReturnType, ...} = vt
in
   setReturnType (f, t)
end

fun getReturnType (vt: varTypes, f) = let
   val {getReturnType, ...} = vt
in
   getReturnType f
end

(* If possible, infer a new return type from `exp` under `vt`

   Only the cases that can change due to flattening are supported.
*)
fun maybeReinferType (vt: varTypes, exp: Exp.t): Type.t option = let
   fun getType v = getVarType (vt, v)
   fun getNthTupleType (n, ty) = let
      val tys = Type.deTuple ty
   in
      Vector.sub (tys, n)
   end
in
   case exp of
       Exp.Select {offset, tuple} =>
       SOME (getNthTupleType (offset, getType tuple))
     | Exp.Tuple vs => SOME (Type.tuple (Vector.map (vs, getType)))
     | Exp.Var v => SOME (getType v)
     (* This case should work, but we don't support it for now *)
     | Exp.ConApp _ => NONE
     (* These types can't be changed due to flattening, no need to update *)
     | Exp.Const _ => NONE
     | Exp.PrimApp _ => NONE
     | Exp.Profile _ => NONE
end

fun propagateResultToLayout (result: (Exp.t * Type.t) option): Layout.t =
    case result of
        SOME (exp, ty) => Layout.seq [Layout.str "(",
                                      Exp.layout exp,
                                      Layout.str ", ",
                                      Type.layout ty,
                                      Layout.str ")"]
      | NONE => Layout.str "(none)"

fun maybePropagateTypesInExp (vt: varTypes, exp: Exp.t): (Exp.t * Type.t) option = let
   fun getType v = getVarType (vt, v)
   fun getNthTupleType (n, ty) = let
      val tys = Type.deTuple ty
   in
      Vector.sub (tys, n)
   end
   fun buildRefDeref (arg, rb) = let
      val targ' = Type.deRef (getType arg)
   in
      (Exp.PrimApp {args = Vector.new1 arg,
                    prim = Prim.Ref_deref rb,
                    targs = Vector.new1 targ'},
      targ')
end
fun buildRefRef (arg) = let
   val targ' = getType arg
in
   (Exp.PrimApp {args = Vector.new1 arg,
                 prim = Prim.Ref_ref,
                 targs = Vector.new1 targ'},
       Type.reff targ')
   end

   fun reinferPrim {args, prim, targs} =
       case prim of
           Prim.Ref_deref rb => SOME (buildRefDeref (getUniqueElement args, rb))
        |  Prim.Ref_ref => SOME (buildRefRef (getUniqueElement args))
        |  _ => NONE

   val result =
       case exp of
           Exp.Select {offset, tuple} =>
           SOME (exp, getNthTupleType (offset, getType tuple))
         | Exp.Tuple vs => SOME (exp, Type.tuple (Vector.map (vs, getType)))
         | Exp.Var v => SOME (exp, getType v)
         (* This case should work, but we don't support it for now *)
         | Exp.ConApp _ => NONE
         (* These types can't be changed due to flattening, no need to update *)
         | Exp.Const _ => NONE
         | Exp.PrimApp prim => reinferPrim prim
         | Exp.Profile _ => NONE
   fun logThunk () =
       Layout.seq [
          Layout.str "maybePropagateTypesInExp: ",
          Layout.str " original: ",
          Exp.layout exp,
          Layout.str ", result=",
          propagateResultToLayout result
       ]
   val _ = Control.diagnostic logThunk
in
   result
end

fun propagateTypesInStatement (vt: varTypes, s: Statement.t):
    Statement.t = let
   fun logThunk () =
      Layout.seq [Layout.str "propagateTypesInStatement: ",
                  Statement.layout s]
   val _ = Control.diagnostic logThunk
   val Statement.T {exp, ty, var} = s
   val (newExp, newTy) =
       (* Update type/exp if necessary, otherwise keep the existing one *)
       case maybePropagateTypesInExp (vt, exp) of
           SOME new => new
         | _ => (exp, ty)
   val _ =
       case var of
           (* Update the type of the bound variable (if any) *)
           SOME v => setVarType (vt, v, newTy)
         | _ => ()
in
   Statement.T {exp = newExp, ty = newTy, var = var}
end

fun markStatementForPolicy (fv: flattenedVars,
                            policy: flattenPolicy)
                           (s: Statement.t): unit =
   case (shouldMarkType (policy, extractType s), Statement.var s) of
       (true, SOME v') => markForFlatten (fv, v')
     | _ => ()

fun markArgForPolicy (fv: flattenedVars, policy: flattenPolicy)
                     ((var, ty): (Var.t * Type.t)): unit =
    setArgFlatteningDecision (fv, var, getConDecisionForPolicy policy ty)

fun markDatatypeForPolicy (fv: flattenedVars, policy: flattenPolicy)
                          (dt: Datatype.t): unit = let
   val Datatype.T {cons, ...} = dt
   fun getDecision ty = getConDecisionForPolicy policy ty
   fun doCon {args, con} =
       setConFlatteningDecision (fv, con, Vector.map (args, getDecision))in
   Vector.foreach (cons, doCon)
end

exception BadFlattenError
fun maybeFlattenArg (fv, (v, t)) = let
   val decision = getArgFlatteningDecision (fv, v)
   val t' = applyConDecision (decision, t)
            handle InvalidConFlattening => raise BadFlattenError
in
   (v, t')
end

fun isArrayPrim prim =
    case prim of
        Prim.Array_alloc _=> true
      | Prim.Array_array  => true
      | Prim.Array_cas _=> true
      | Prim.Array_copyArray  => true
      | Prim.Array_copyVector  => true
      | Prim.Array_length  => true
      | Prim.Array_sub _=> true
      | Prim.Array_toArray  => true
      | Prim.Array_toVector  => true
      | Prim.Array_uninit  => true
      | Prim.Array_uninitIsNop  => true
      | Prim.Array_update _  => true
      | _ =>  false

fun isVectorPrim prim =
    case prim of
        Prim.Vector_length => true
      | Prim.Vector_sub =>  true
      | Prim.Vector_vector =>  true
      (* TODO: more cases *)
      | _ =>  false

fun isContainerPrim prim =
    isArrayPrim prim orelse
    isVectorPrim prim

(* Given the `targs` of a vector/array, returns the corresponding flattened type

    {('a * 'b), Prim.Array_...} -> 'a array * 'b array
    {('a * 'b), Prim.Vector_...} -> 'a array * 'b array

 *)
fun getFlattenedPrimTArg (prim, targs) =
    case (isArrayPrim prim, isVectorPrim prim, Vector.length targs) of
        (true, false, 1) =>
       (* Wrap in `array` to get the array type:
             Array_alloc['a * b'] ->
             ('a * 'b) array
        *)
       maybeFlattenType (Type.array (Vector.first targs))
     | (false, true, 1) => 
       maybeFlattenType (Type.vector (Vector.first targs))
     | _ => NONE

(* Given flattened array/vector targs, returns the nth element type

  ('a array * 'b array, 0) -> 'a
 *)
fun getNthElemType (flatArg, idx) = let
   (* {'a, 'b } *)
   val components = getFlattenedElementTypes flatArg
in
   (* -> 'a *)
   Vector.sub (components, idx)
end

(* {('a * 'b * ...), 1}
   ->
   'b
 *)
fun getNthTupleType (t: Type.t, idx: int) = let
   val elts = Type.deTuple t
in
   Vector.sub (elts, idx)
end


(* ('a array * 'b array) tuple -> 2  *)
fun getNumElementTypes flatArg = let
   (* {'a array, 'b array} *)
   val components = Type.deTuple flatArg
in
   Vector.length components
end

fun concatVecs (vecs: 'a vector list): 'a vector =
    Vector.concatV (Vector.fromList vecs)

fun maybeStmtsToLayout (maybeStmts: Statement.t vector option) =
    case maybeStmts of
        SOME ss => Layout.align (Vector.toList (Vector.map (ss, Statement.layout)))
      | NONE => Layout.str "(none)"

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
      fun mkLogResultThunk (res) = let
         fun logThunk() = Layout.seq [
                Layout.str "Result: ",
                maybeStmtsToLayout res
             ]
      in
         logThunk
      end
      (* flatBind = Array_alloc[targ](n)
         `primArg` is {raw=true/false}`
       *)
      fun mkAlloc primArg targ =  let
         val allocExp = Exp.PrimApp {args=args,
                                     prim=Prim.Array_alloc primArg,
                                     targs=Vector.new1 targ}
      in
         Statement.T {exp = allocExp,
                      ty = Type.array targ,
                      var = SOME (Var.newString "flatBind")}
      end
      (* arr_n = select(arr, n) *)
      fun mkSelect (flatArg, from) idx = let
         val arrTy = getNthTupleType (flatArg, idx)
         val selectExp = Exp.Select {offset = idx,
                                     tuple = from}
         val varBasename = "flatArr_" ^ (Int.toString idx)
         val newVar = Var.newString varBasename
      in
         Statement.T {exp = selectExp,
                      ty = arrTy,
                      var = SOME newVar}
      end
      (* arr: 'a array = ...
         ->
         x = Array_sub['a](arr, n)

         Assumes `prim` is `Vector_sub` or `Array_sub`
       *)
      fun mkLoad (stmt: Statement.t): Statement.t = let
         val Statement.T {ty=arrTy, ...} = stmt
         val elTy = deContainer arrTy
         val idxArg = Vector.sub (args, 1)
         val subExp = Exp.PrimApp {args = Vector.new2 (extractBind stmt, idxArg),
                                   prim = prim,
                                   targs = Vector.new1 elTy}
      in
         Statement.T {
            exp = subExp,
            ty = elTy,
            var = SOME (Var.newString "flatLoad")}

      end
      (* {x_arr: 'a array = ...; x: 'a = ...}
         ->
         _ = Array_update(x_arr, n, x)

         `primArg` is `{writeBarrier=true/false}`
      *)
      fun mkStore primArg (arrStmt: Statement.t, varStmt: Statement.t): Statement.t = let
         val Statement.T {ty=elTy, ...} = varStmt
         val idxArg = Vector.sub (args, 1)
         val storeExp = Exp.PrimApp {args = Vector.new3 (extractBind arrStmt,
                                                         idxArg,
                                                         extractBind varStmt),
                                     prim = Prim.Array_update primArg,
                                     targs = Vector.new1 elTy}
      in
         Statement.T {
            exp = storeExp,
            ty = Type.unit,
            var = NONE}

      end

      (* v1: 'a = ...
         v2: 'b = ...
         ...
         -->
         bindTo: ('a * b * ...) = tuple (v1, v2, ...)
      *)
      fun mkTuple (bindTo: Var.t option,
                   stmts: Statement.t vector): Statement.t = let
         val binds = Vector.map (stmts, extractBind)
         val tys = Vector.map (stmts, extractType)
         val tupleExp = Exp.Tuple binds
      in
         Statement.T {exp = tupleExp,
                      ty = Type.tuple tys,
                      var = bindTo}
      end
      (* arr: 'a array = ....
         ->
         vec: 'a vec = Array_toVector['a](arr)
      *)
      fun mkArrToVec (arrStmt: Statement.t): Statement.t = let
         val elTy = Type.deArray (extractType arrStmt)
         val toVecExp = Exp.PrimApp {args = Vector.new1 (extractBind arrStmt),
                                     prim = Prim.Array_toVector,
                                     targs = Vector.new1 elTy}
      in
         Statement.T {exp = toVecExp,
                      ty = Type.vector elTy,
                      var = SOME (Var.newString "flatVec")}
      end
      (* arr: 'a array = ....
         ->
         arr': 'a array = Array_toArray['a](arr)
      *)
      fun mkArrayToArray (arrStmt: Statement.t): Statement.t = let
         val elTy = Type.deArray (extractType arrStmt)
         val arrayToArrayExp = Exp.PrimApp {args = Vector.new1 (extractBind arrStmt),
                                            prim = Prim.Array_toArray,
                                            targs = Vector.new1 elTy}
      in
         Statement.T {exp = arrayToArrayExp,
                      ty = Type.array elTy,
                      var = SOME (Var.newString "flatArr")}
      end
      fun buildArrayAlloc (primArg, flatArg) = let
         val components = getFlattenedElementTypes flatArg
         (*
            arr_a = Array_Alloc['a]
            arr_b = Array_Alloc['b]
            ...
         *)
         val newAllocs = Vector.map (components, mkAlloc primArg)
         (* arr = tuple (arr_a, arr_b, ...) *)
         val newTuple = Statement.T {
                exp=Exp.Tuple (Vector.map (newAllocs, extractBind)),
                ty=flatArg,
                var=var
             }
      in
         (*
           arr_a = ...
           arr_b = ...
           ...
           arr = tuple (...)

          TODO(pscollins): For some reason, `Vector.concat` fails
         *)
         Vector.concatV (Vector.fromList [newAllocs, Vector.new1 newTuple])
      end
      fun buildArrayLength flatArg = let
         val elemTy = getNthElemType (flatArg, 0)
         (* arr_a = select(arr, 0) *)
         val arrStmt = mkSelect (flatArg, Vector.first args) 0
         (* Array_length['a](arr_a) *)
         val lenExp = Exp.PrimApp {args = Vector.new1 (extractBind arrStmt),
                                   (* Pick either `Array_` or `Vector_` length *)
                                   prim = prim,
                                   targs = Vector.new1 elemTy}
         (* len: int = $lenExp *)
         val lenStmt = Statement.T {exp = lenExp,
                                    ty = ty,
                                    var = var}
      in
         (*
            arr_a: 'a array = select(arr, 0)
            len: int = Array_length['a](arr_a)
         *)
         Vector.new2 (arrStmt, lenStmt)
      end
      fun buildArraySub flatArg = let
         val numTypes = getNumElementTypes flatArg
         (* arr_a = select(arr, 0)
            arr_b = select(arr, 1)
            ...
          *)
         val arrValue = Vector.first args
         val selectStmts = Vector.tabulate (numTypes,
                                            mkSelect (flatArg, arrValue))
         (* x_a = Array_sub['a](arr_a, n)
            x_b = Array_sub['b](arr_b, n)
            ...
          *)
         val loadStmts = Vector.map (selectStmts, mkLoad)
         (* res = tuple (x_a, x_b, ...) *)
         val tupleStmt = mkTuple (var, loadStmts)
      in
         concatVecs [selectStmts,
                     loadStmts,
                     Vector.new1 tupleStmt]
      end
      fun buildArrayUpdate (primArg, flatArg) = let
         val numTypes = getNumElementTypes flatArg
         (* arr_a = select(arr, 0)
            arr_b = select(arr, 1)
            ...
          *)
         val arrValue = Vector.first args
         val selectArrs = Vector.tabulate (numTypes, mkSelect (flatArg,
                                                               arrValue))
         (* x_a = select(x, 0)
            x_b = select(x, 1)
            ...
          *)
         val xValue = Vector.last args
         (* ('a, 'b, ...) *)
         val xTypes = Type.tuple (getFlattenedElementTypes flatArg)
         val selectVars = Vector.tabulate (numTypes, mkSelect (xTypes,
                                                               xValue))
         (* _ = Array_update['a](arr_a, n, x_a)
            _ = Array_update['b](arr_b, n, x_b)
            ...
         *)
         val storeStmts = Vector.map2 (selectArrs, selectVars, mkStore primArg)
      in
         concatVecs [selectArrs,
                     selectVars,
                     storeStmts]
      end
      fun buildArrayToVector flatArg = let
         val numTypes = getNumElementTypes flatArg
         (* arr_a = select(arr, 0)
            arr_b = select(arr, 1)
            ...
          *)
         val arrValue = Vector.first args
         val selectArrs = Vector.tabulate (numTypes, mkSelect (flatArg,
                                                               arrValue))
         (* vec_a = Array_toVector['a](arr_a)
            vec_b = Array_toVector['b](arr_b)
            ...
         *)
         val vecStmts = Vector.map (selectArrs, mkArrToVec)
         (* vec = (vec_a * vec_b * ...) *)
         val tupleStmt = mkTuple (var, vecStmts)
      in
         concatVecs [selectArrs,
                     vecStmts,
                     Vector.new1 tupleStmt]
      end
      fun buildArrayUninitIsNop () = let
         (* For now, just hardcode false: since the original elements were
          tuples, this should be no-worse performance than we had before
          (although it might waste some performance in case we could have
          avoided doing this initialization on the flattened elements) *)
         val falseExp = Exp.ConApp {con = Con.falsee,
                                    args = Vector.new0()}
         val assignStmt = Statement.T {exp = falseExp,
                                       ty = Type.bool,
                                       var = var}
      in
         Vector.new1 assignStmt
      end
      fun buildArrayToArray flatArg = let
         val numTypes = getNumElementTypes flatArg
         (* arr_a = select(arr, 0)
            arr_b = select(arr, 1)
            ...
          *)
         val arrValue = Vector.first args
         val selectArrs = Vector.tabulate (numTypes, mkSelect (flatArg,
                                                               arrValue))
         (* arr'_a = Array_toArray['a](arr_a)
            arr'_b = Array_toArray['b](arr_b)
            ...
         *)
         val newArrStmts = Vector.map (selectArrs, mkArrayToArray)
         (* arr' = (arr'_a * arr'_b * ...) *)
         val tupleStmt = mkTuple (var, newArrStmts)
      in
         concatVecs [selectArrs,
                     newArrStmts,
                     Vector.new1 tupleStmt]
      end
      val result =
          case (prim, getFlattenedPrimTArg (prim, targs))  of
              (Prim.Array_alloc primArg, SOME flatArg) =>
              SOME (buildArrayAlloc (primArg, flatArg))
            | (Prim.Array_length, SOME flatArg) =>
              SOME (buildArrayLength flatArg)
            | (Prim.Vector_length, SOME flatArg) =>
              SOME (buildArrayLength flatArg)
            | (Prim.Array_sub primArg, SOME flatArg) =>
              SOME (buildArraySub flatArg)
            | (Prim.Vector_sub, SOME flatArg) =>
              SOME (buildArraySub flatArg)
            | (Prim.Array_update primArg, SOME flatArg) =>
              SOME (buildArrayUpdate (primArg, flatArg))
            | (Prim.Array_toVector, SOME flatArg) =>
              SOME (buildArrayToVector flatArg)
            | (Prim.Array_uninitIsNop, _) =>
              (* This prim has an array-valued targ, so it returns NONE *)
              SOME (buildArrayUninitIsNop ())
            | (Prim.Array_toArray, SOME flatArg) =>
              SOME (buildArrayToArray flatArg)
            | _ => NONE
      val _ = Control.diagnostic (mkLogResultThunk result)
   in
      result
   end
in
   case exp of
       Exp.PrimApp {args, prim, targs} =>
       if isContainerPrim prim then
          doPrimApp (args, prim, targs)
       else SOME (Vector.new1 s)
     | _ => SOME (Vector.new1 s)
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

exception IllegalFlatteningDecision
fun flattenStatements fv ss = let
   fun mkLogThunk s = let
      fun thunk() =
          Layout.seq [Layout.str "Maybe flatten? ",
                      Statement.layout s]
   in
      thunk
   end
   fun doStmt s = let
      val _ = Control.diagnostic (mkLogThunk s)
      in
         case (mustFlattenStatement (fv, s),
               maybeFlattenStatement s) of
             (false, _) => Vector.new1 s
           | (true, SOME ss) => ss
           (* For now, we only report missing flattening for PrimApp *)
           | (true, NONE) => raise IllegalFlatteningDecision
      end
in
   Vector.concatV (Vector.map (ss, doStmt))
end

fun flattenArgs fv args = let
   fun doArg (t as (v, _)) =
       maybeFlattenArg (fv, t)
in
   Vector.map (args, doArg)
end

fun flattenDatatype (fv: flattenedVars)
                    (dt: Datatype.t): Datatype.t = let
   val Datatype.T {cons, tycon} = dt
   fun applyDecision (cd, t) =
       applyConDecision (cd, t)
       handle InvalidConFlattening => raise IllegalFlatteningDecision
   fun maybeFlattenCon {args, con} = let
      val decisions = getConFlatteningDecision (fv, con)
      val args = Vector.map2 (decisions, args, applyDecision)   in
      {args = args, con = con}
   end
in
   Datatype.T {cons = Vector.map (cons, maybeFlattenCon),
               tycon = tycon}
end

fun getFlattenedVarsInProgram (policy: flattenPolicy, p: Program.t) = let
   val Program.T {datatypes, ...} = p
   val fv = newFlattenedVars()
   fun foreachStatements ss =
       Vector.foreach(ss, markStatementForPolicy (fv, policy))
   fun foreachArgs args =
       Vector.foreach (args, markArgForPolicy (fv, policy))
   fun foreachTransfer _ = ()

   val visitor = {
      foreachStatements = foreachStatements,
      foreachArgs = foreachArgs,
      foreachTransfer = foreachTransfer
   }
   val _ = foreachBfs visitor p
   val _ = Vector.foreach (datatypes, markDatatypeForPolicy (fv, policy))
in
   fv
end

fun bindTypeInStatement (vt, s) = let
   val Statement.T {var, ty, ...} = s
in
   case var of
       SOME v' => setVarType (vt, v', ty)
     | _ => ()
end

fun bindTypesInArgs (vt: varTypes)
                    (args: (Var.t * Type.t) vector): (Var.t * Type.t) vector
    = let
   fun bindType (v, t) =
       setVarType (vt, v, t)
in
   (Vector.foreach (args, bindType); args)
end

fun flattenDatatypesInProgram (fv: flattenedVars, p: Program.t): Program.t = let
   val Program.T {datatypes, functions, globals, main} = p
in
   Program.T {datatypes = Vector.map (datatypes, flattenDatatype fv),
              functions = functions,
              globals = globals,
              main = main}
end

fun layoutReturns (returns: Type.t vector option): Layout.t =
    Option.layout (Vector.layout Type.layout) returns

exception InconsistentTypes
fun propagateReturnTypes (vt: varTypes, f: Function.t): Type.t vector option = let
   val {returns, ...} = Function.dest f
   fun getType v = getVarType (vt, v)
   fun getReturnTy (b: Block.t): Type.t vector =
       case Block.transfer b of
           Transfer.Return (vs) => Vector.map (vs, getType)
         | _ => Vector.new0()
   fun mergeReturnTys (l: Type.t vector, r: Type.t vector) =
       case (Vector.length l, Vector.length r) of
           (* We use emtpy vectors to encode non-Return transfers: if at least
           one side is empty, return the other one *)
           (0, 0) => l
         | (0, y) => r
         | (x, 0) => l
         | (x, y) =>
           if Vector.forall2 (l, r, Type.equals) then l
           else raise InconsistentTypes
   fun mergeAllReturnTys (types: Type.t vector vector) =
       if Vector.length types > 0 then
          Vector.fold (types, Vector.first types, mergeReturnTys)
       else raise InconsistentTypes
   val newReturns =
       (* We might be able to simplify this a bit by skipping the `returns`
          check, but this will give us a clear type error if something goes wrong *)
       case returns of
           SOME _ =>
           SOME (mergeAllReturnTys (Vector.map (Function.blocks f, getReturnTy)))
         | NONE => NONE
   fun logThunk () =
       Layout.seq [
          Layout.str "propagateReturnTypes f=",
          Func.layout (Function.name f),
          Layout.str ", old=",
          layoutReturns returns,
          Layout.str ", new=",
          layoutReturns newReturns
       ]
   val _ = Control.diagnostic logThunk
in
   newReturns
end

(* Applies `propgatateReturnTypes` to every function in `p` *)
fun propagateAllReturnTypes (vt: varTypes, p: Program.t): Program.t = let
   val Program.T {datatypes, functions, globals, main} = p
   fun doPropagate f = let
      val {args, blocks, inline, name, raises, returns, start} =
          Function.dest f
   in
      Function.new {args = args,
                    blocks = blocks,
                    inline = inline,
                    name = name,
                    raises = raises,
                    returns = propagateReturnTypes (vt, f),
                    start = start}
   end
in
   Program.T {datatypes = datatypes,
              functions = List.map (functions, doPropagate),
              globals = globals,
              main = main}
end

fun flattenOnce (policy: flattenPolicy) (p: Program.t): Program.t option = let
   (* First pass: collect all of the variables in the program that need
   flattening *)
   val fv = getFlattenedVarsInProgram (policy, p)
   val rewriter = {
      doStatements = flattenStatements fv,
      doArgs = flattenArgs fv,
      doTransfer = fn x => x
   }
   val p' = rewriteBfs rewriter p
   val count = markedCount fv

   (* Second pass: propagate types + update datatype declarations *)
   val vt = newVarTypes ()
   fun propagateThroughStatements ss = let
      fun doStmt s = let
         val Statement.T {var, ty, ...} = s
         (* Set the initial type before tyring to propagate *)
         val _ = bindTypeInStatement (vt, s)
      in
         propagateTypesInStatement (vt, s)
      end
   in
      Vector.map (ss, doStmt)
   end
   val propagator = {
      doStatements = propagateThroughStatements,
      doArgs = bindTypesInArgs vt,
      doTransfer = fn x => x
   }
   val p'' = propagateAllReturnTypes (vt,
                                      flattenDatatypesInProgram (fv, rewriteBfs propagator p'))
   (* Cleanup *)
   val _ = destroyVarTypes vt
   val _ = destroyFlattenedVars fv
in
   if count > 0 then SOME p''
   else NONE
end


fun transform (p: Program.t): Program.t =
    let
       val policy =
           case !Control.shallowFlattenPolicy of
               Control.ShallowFlattenPolicy.MaxWidth n => MaxWidth n
       fun loop (p, n) =
          if n >= !Control.shallowFlattenMaxIters
             then p
          else
             case flattenOnce policy p of
                NONE => p
              | SOME p' => loop (p', n + 1)
    in
       loop (p, 0)
    end
end
