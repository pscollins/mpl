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
structure CoreMLUtil = CoreMLUtil (structure CoreML = CoreML)
open CoreMLUtil

val _ = print "Testing toVerboseString...\n"

val _ =
   let
      open Atoms
      val x = Var.newString "x"
      val ty = CoreML.Type.unit
      
      val expX = CoreML.Exp.var (x, ty)
      val s = toVerboseStringExp expX
      val _ = print (s ^ "\n")
      (* Expecting something like: Exp.make (Exp.Var (x, []), unit) *)
      val _ = if String.hasSubstring (s, {substring = "Exp.Var (x"}) then () else Error.bug "toVerboseStringExp failed"

      val patX = CoreML.Pat.var (x, ty)
      val s = toVerboseStringPat patX
      val _ = print (s ^ "\n")
      (* Expecting something like: Pat.make (Pat.Var x, unit) *)
      val _ = if String.hasSubstring (s, {substring = "Pat.Var x"}) then () else Error.bug "toVerboseStringPat failed"

      val dec = CoreML.Dec.Val {
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
               pat = patX,
               regionPat = Region.bogus
            }
         }
      val s = toVerboseStringDec dec
      val _ = print (s ^ "\n")
      val _ = if String.hasSubstring (s, {substring = "Dec.Val"}) then () else Error.bug "toVerboseStringDec failed"
      val _ = if String.hasSubstring (s, {substring = "rvbs=[]"}) then () else Error.bug "toVerboseStringDec failed (rvbs)"
      val _ = if String.hasSubstring (s, {substring = "vbs=[{exp="}) then () else Error.bug "toVerboseStringDec failed (vbs)"
   in
      ()
   end

val _ = print "Tests Passed\n"
