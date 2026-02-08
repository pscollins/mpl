structure Atoms = Atoms ()
structure TypeEnv = TypeEnv (open Atoms)
structure CoreML = CoreML (open Atoms
                           structure Type =
                              struct
                                 open TypeEnv.Type

                                 val makeHom =
                                    fn {con, var} =>
                                    makeHom {con = con,
                                             expandOpaque = true,
                                             var = var}

                                 fun layout t =
                                    #1 (layoutPretty
                                        (t, {expandOpaque = true,
                                             layoutPrettyTycon = Tycon.layout,
                                             layoutPrettyTyvar = Tyvar.layout}))
                              end)
structure InlineTrace = InlineTrace (structure CoreML = CoreML)
structure AnnotateTrace = AnnotateTrace (structure CoreML = CoreML)
structure CoreMLUtil = CoreMLUtil (structure CoreML = CoreML)
open CoreMLUtil

val _ = print "Instantiated all functors.\n"

val emptyProg = Vector.fromList []
val _ = InlineTrace.inlineTrace {prog = emptyProg}
val _ = AnnotateTrace.annotateTrace {prog = emptyProg}

val _ = decId []

val _ = print "Testing collectVarsBoundToPred...\n"

val _ =
   let
      open Atoms
      val x = Var.newString "x"
      val y = Var.newString "y"
      val z = Var.newString "z"
      val ty = CoreML.Type.unit

      fun mkValDec (var, exp) =
         CoreML.Dec.Val {
            matchDiags = {nonexhaustiveExn = Control.Elaborate.DiagDI.Default,
                          nonexhaustive = Control.Elaborate.DiagEIW.Ignore,
                          redundant = Control.Elaborate.DiagEIW.Ignore},
            rvbs = Vector.new0 (),
            tyvars = fn () => Vector.new0 (),
            vbs = Vector.new1 {
               ctxt = fn () => Layout.empty,
               exp = exp,
               layPat = fn () => Layout.empty,
               nest = [],
               pat = CoreML.Pat.var (var, ty),
               regionPat = Region.bogus
            }
         }

      val expX = CoreML.Exp.var (x, ty)
      val expY = CoreML.Exp.var (y, ty)

      val dec1 = mkValDec (x, expY) (* x = y *)
      val dec2 = mkValDec (y, expX) (* y = x *)
      val dec3 = mkValDec (z, expX) (* z = x *)

      val prog = Vector.fromList [[dec1], [dec2, dec3]]

      fun isVarX e =
         case CoreML.Exp.node e of
            CoreML.Exp.Var (v, _) => Var.equals (v (), x)
          | _ => false

      val res = collectVarsBoundToPred (prog, isVarX)
      val _ = if List.length (VarSet.toList res) = 2 then () else Error.bug "Test failed: wrong size"

      fun contains (s, v) =
         not (VarSet.isEmpty (VarSet.intersect (s, VarSet.singleton v)))

      val _ = if contains (res, y) then () else Error.bug "Test failed: missing y"
      val _ = if contains (res, z) then () else Error.bug "Test failed: missing z"
      val _ = if contains (res, x) then Error.bug "Test failed: contains x" else ()

      (* Test multiple bindings - should be ignored *)
      val decMultiple = CoreML.Dec.Val {
            matchDiags = {nonexhaustiveExn = Control.Elaborate.DiagDI.Default,
                          nonexhaustive = Control.Elaborate.DiagEIW.Ignore,
                          redundant = Control.Elaborate.DiagEIW.Ignore},
            rvbs = Vector.new0 (),
            tyvars = fn () => Vector.new0 (),
            vbs = Vector.new2 ({
               ctxt = fn () => Layout.empty,
               exp = expX,
               layPat = fn () => Layout.empty,
               nest = [],
               pat = CoreML.Pat.var (y, ty),
               regionPat = Region.bogus
            }, {
               ctxt = fn () => Layout.empty,
               exp = expX,
               layPat = fn () => Layout.empty,
               nest = [],
               pat = CoreML.Pat.var (z, ty),
               regionPat = Region.bogus
            })
         }
      val res2 = collectVarsBoundToPred (Vector.fromList [[decMultiple]], isVarX)
      val _ = if VarSet.isEmpty res2 then () else Error.bug "Test failed: decMultiple should be ignored"

      (* Test non-variable pattern - should be ignored *)
      val decWild = CoreML.Dec.Val {
            matchDiags = {nonexhaustiveExn = Control.Elaborate.DiagDI.Default,
                          nonexhaustive = Control.Elaborate.DiagEIW.Ignore,
                          redundant = Control.Elaborate.DiagEIW.Ignore},
            rvbs = Vector.new0 (),
            tyvars = fn () => Vector.new0 (),
            vbs = Vector.new1 {
               ctxt = fn () => Layout.empty,
               exp = expX,
               layPat = fn () => Layout.empty,
               nest = [],
               pat = CoreML.Pat.wild ty,
               regionPat = Region.bogus
            }
         }
      val res3 = collectVarsBoundToPred (Vector.fromList [[decWild]], isVarX)
      val _ = if VarSet.isEmpty res3 then () else Error.bug "Test failed: decWild should be ignored"

      (* Test recursive bindings - should be ignored *)
      val decRvbs = CoreML.Dec.Val {
            matchDiags = {nonexhaustiveExn = Control.Elaborate.DiagDI.Default,
                          nonexhaustive = Control.Elaborate.DiagEIW.Ignore,
                          redundant = Control.Elaborate.DiagEIW.Ignore},
            rvbs = Vector.new1 {
               lambda = CoreML.Lambda.bogus,
               var = y
            },
            tyvars = fn () => Vector.new0 (),
            vbs = Vector.new0 ()
         }
      val res4 = collectVarsBoundToPred (Vector.fromList [[decRvbs]], isVarX)
      val _ = if VarSet.isEmpty res4 then () else Error.bug "Test failed: decRvbs should be ignored"
   in
      ()
   end

val _ = print "Testing mapExps...\n"

val _ =
   let
      open Atoms
      val x = Var.newString "x"
      val y = Var.newString "y"
      val z = Var.newString "z"
      val ty = CoreML.Type.unit

      fun mkValDec (var, exp) =
         CoreML.Dec.Val {
            matchDiags = {nonexhaustiveExn = Control.Elaborate.DiagDI.Default,
                          nonexhaustive = Control.Elaborate.DiagEIW.Ignore,
                          redundant = Control.Elaborate.DiagEIW.Ignore},
            rvbs = Vector.new0 (),
            tyvars = fn () => Vector.new0 (),
            vbs = Vector.new1 {
               ctxt = fn () => Layout.empty,
               exp = exp,
               layPat = fn () => Layout.empty,
               nest = [],
               pat = CoreML.Pat.var (var, ty),
               regionPat = Region.bogus
            }
         }

      val expX = CoreML.Exp.var (x, ty)
      val expY = CoreML.Exp.var (y, ty)
      val nodeX = CoreML.Exp.node expX
      val nodeY = CoreML.Exp.node expY

      fun isVarX node =
         case node of
            CoreML.Exp.Var (v, _) => Var.equals (v (), x)
          | _ => false

      fun replaceXWithY node =
         if isVarX node then SOME nodeY else NONE

      (* Test 1: Simple replacement *)
      val prog1 = Vector.fromList [[mkValDec (z, expX)]]
      val res1 = mapExps (prog1, replaceXWithY)

      fun getFirstExp prog =
         case Vector.sub (prog, 0) of
            [CoreML.Dec.Val {vbs, ...}] => #exp (Vector.sub (vbs, 0))
          | _ => Error.bug "Test failed: unexpected program structure"

      fun isVarY e =
         case CoreML.Exp.node e of
            CoreML.Exp.Var (v, _) => Var.equals (v (), y)
          | _ => false

      val _ = if isVarY (getFirstExp res1) then () else Error.bug "Test 1 failed: x not replaced by y"

      (* Test 2: Nested replacement *)
      val letExp = CoreML.Exp.make (CoreML.Exp.Let (Vector.new1 (mkValDec (z, expX)), expX), ty)
      val prog2 = Vector.fromList [[mkValDec (y, letExp)]]
      val res2 = mapExps (prog2, replaceXWithY)

      fun checkNested res =
         case CoreML.Exp.node (getFirstExp res) of
            CoreML.Exp.Let (decs, body) =>
               let
                  val dec = Vector.sub (decs, 0)
                  val innerExp = case dec of
                                    CoreML.Dec.Val {vbs, ...} => #exp (Vector.sub (vbs, 0))
                                  | _ => Error.bug "Unexpected dec"
               in
                  isVarY innerExp andalso isVarY body
               end
          | _ => false

      val _ = if checkNested res2 then () else Error.bug "Test 2 failed: nested x not replaced by y"

      (* Test 3: No recursion after SOME *)
      (* Replace x with (let val z = x in z end). 
         If it recurses, it will replace the inner x too.
         If it doesn't, the inner x remains x. *)
      val replacementNode = CoreML.Exp.Let (Vector.new1 (mkValDec (z, expX)), CoreML.Exp.var (z, ty))
      fun replaceXWithLet node =
         if isVarX node then SOME replacementNode else NONE

      val prog3 = Vector.fromList [[mkValDec (y, expX)]]
      val res3 = mapExps (prog3, replaceXWithLet)

      fun checkNoRecursion res =
         case CoreML.Exp.node (getFirstExp res) of
            CoreML.Exp.Let (decs, _) =>
               let
                  val dec = Vector.sub (decs, 0)
                  val innerExp = case dec of
                                    CoreML.Dec.Val {vbs, ...} => #exp (Vector.sub (vbs, 0))
                                  | _ => Error.bug "Unexpected dec"
               in
                  case CoreML.Exp.node innerExp of
                     CoreML.Exp.Var (v, _) => Var.equals (v (), x)
                   | _ => false
               end
          | _ => false

      val _ = if checkNoRecursion res3 then () else Error.bug "Test 3 failed: recursed after SOME"
   in
      ()
   end

val _ = print "Tests Passed\n"
