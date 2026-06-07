structure SmlString = String
local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else raise TestFail msg

   fun statementEquals (Statement.T {exp=e1, ty=t1, var=v1},
                        Statement.T {exp=e2, ty=t2, var=v2}) =
      Exp.equals (e1, e2) andalso
      Type.equals (t1, t2) andalso
      (case (v1, v2) of
          (SOME v1', SOME v2') => Var.equals (v1', v2')
        | (NONE, NONE) => true
        | _ => false)

   fun assertType (Statement.T {ty, ...}, expected, msg) =
      if Type.equals (ty, expected) then ()
      else assert (false, msg ^ ": type mismatch")

   fun isFlatten cd =
      case cd of
         ShallowFlatten.FlattenNode _ => true
       | _ => false
in
(* Test 26: Nested Tuple constructors *)
   val _ = runTest ("Test 26: Nested Tuple constructors", fn () => let
      val mainFunc = Func.fromString "main"
      val L0 = Label.fromString "L0"
      val n = Var.fromString "n"
      val other = Var.fromString "other"
      val x = Var.fromString "x"
      val y = Var.fromString "y"
      val z = Var.fromString "z"
      
      val intTy = Type.intInf
      val word32Ty = Type.word WordSize.word32
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty

      val s1 = Statement.T {
         exp = Exp.PrimApp {args = Vector.new1 n,
                            prim = Prim.Array_alloc {raw = false},
                            targs = Vector.new1 tuple2Ty},
         ty = arrayTuple2Ty,
         var = SOME x
      }
      
      val s2 = Statement.T {
         exp = Exp.Tuple (Vector.fromList [x, other]),
         ty = Type.tuple (Vector.fromList [arrayTuple2Ty, word32Ty]),
         var = SOME y
      }

      val s3 = Statement.T {
         exp = Exp.Tuple (Vector.fromList [y, other]),
         ty = Type.tuple (Vector.fromList [Type.tuple (Vector.fromList [arrayTuple2Ty, word32Ty]), word32Ty]),
         var = SOME z
      }

      val mainBlock = Block.T {
         args = Vector.fromList [(n, intTy), (other, word32Ty)],
         label = L0,
         statements = Vector.fromList [s1, s2, s3],
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = L0
      }
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val policy = ShallowFlatten.MaxWidth 2
      val res = ShallowFlatten.flattenOnce policy p
      val p' = case res of
                  SOME p' => p'
                | NONE => raise TestFail "Should have flattened"
      
      val Program.T {functions = funcs', ...} = p'
      val mainFunction' = List.first funcs'
      val {blocks = blocks', ...} = Function.dest mainFunction'
      val block' = Vector.sub (blocks', 0)
      val stmts' = Block.statements block'
      
      (* Check the type of z in the rewritten stmts *)
      val z_stmt = Vector.last stmts'
      val Statement.T {ty = z_ty, ...} = z_stmt
      
      val flattenedXty = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])
      val expectedYty = Type.tuple (Vector.fromList [flattenedXty, word32Ty])
      val expectedZty = Type.tuple (Vector.fromList [expectedYty, word32Ty])
      
      val _ = if Type.equals (z_ty, expectedZty) then ()
              else assert (false, "z type mismatch: " ^ (Layout.toString (Type.layout z_ty)) ^ 
                                 " expected " ^ (Layout.toString (Type.layout expectedZty)))
   in () end)(* Test 27: non-PrimApp flattening (array) *)
   val _ = runTest ("Test 27: non-PrimApp flattening (array)", fn () => let
      val v1 = Var.newString "v1"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = arrayTuple2Ty,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
      val ss = case res of
                  SOME ss => ss
                | NONE => raise TestFail "Should return SOME (original) for non-PrimApp"
      val _ = assert (Vector.length ss = 1, "Should result in exactly one statement")
      val s' = Vector.sub (ss, 0)
   in
      assert (statementEquals (s, s'), "Resulting statement should be the original")
   end)(* Test 28: non-PrimApp flattening (vector) *)
   val _ = runTest ("Test 28: non-PrimApp flattening (vector)", fn () => let
      val v1 = Var.newString "v1"
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val vectorTuple2Ty = Type.vector tuple2Ty
      
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = vectorTuple2Ty,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
      val ss = case res of
                  SOME ss => ss
                | NONE => raise TestFail "Should return SOME (original) for non-PrimApp"
      val _ = assert (Vector.length ss = 1, "Should result in exactly one statement")
      val s' = Vector.sub (ss, 0)
   in
      assert (statementEquals (s, s'), "Resulting statement should be the original")
   end)(* Test 29: non-PrimApp no-flattening (not a tuple) *)
   val _ = runTest ("Test 29: non-PrimApp no-flattening (not a tuple)", fn () => let
      val v1 = Var.newString "v1"
      val intTy = Type.intInf
      val arrayIntTy = Type.array intTy
      
      val s = Statement.T {
         exp = Exp.Var v1,
         ty = arrayIntTy,
         var = SOME (Var.newString "x")
      }

      val res = ShallowFlatten.maybeFlattenStatement s
   in
      case res of
          SOME ss => assert (Vector.length ss = 1 andalso statementEquals (s, Vector.sub (ss, 0)), 
                            "Should return SOME (original)")
        | NONE => raise TestFail "Should return SOME (original)"
   end)
   (* Test 41: flattenOnce with datatypes *)
   val _ = runTest ("Test 41: flattenOnce with datatypes", fn () => let
      val policy = ShallowFlatten.MaxWidth 3
      val intTy = Type.intInf
      val tuple2Ty = Type.tuple (Vector.fromList [intTy, intTy])
      val arrayTuple2Ty = Type.array tuple2Ty
      val flattenedTuple2Ty = Type.tuple (Vector.fromList [Type.array intTy, Type.array intTy])

      val tycon = Tycon.fromString "t"
      val con1 = Con.fromString "Con1"
      val dt = Datatype.T {
         tycon = tycon,
         cons = Vector.new1 {con = con1, args = Vector.new1 arrayTuple2Ty}
      }

      val mainFunc = Func.fromString "main"
      val mainLabel = Label.fromString "L0"
      val v1 = Var.fromString "v1"
      val n = Var.fromString "n"
      
      (* v1 = Array_alloc[ (int * int) array ](n) *)
      val s1 = Statement.T {
         exp = Exp.PrimApp {
            args = Vector.new1 n,
            prim = Prim.Array_alloc {raw = false},
            targs = Vector.new1 tuple2Ty
         },
         ty = arrayTuple2Ty,
         var = SOME v1
      }

      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.new1 s1,
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new1 (n, Type.intInf),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
      }
      val p = Program.T {
         datatypes = Vector.new1 dt,
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }

      val p' = case ShallowFlatten.flattenOnce policy p of
                  SOME p' => p'
                | NONE => raise TestFail "flattenOnce failed to flatten"

      val Program.T {datatypes = dts', ...} = p'
      val dt' = Vector.sub (dts', 0)
      val Datatype.T {cons = cons', ...} = dt'
      val {args = args1, ...} = Vector.sub (cons', 0)
      
      val _ = assert (Type.equals (Vector.sub (args1, 0), flattenedTuple2Ty), 
                      "Datatype should be flattened in flattenOnce")
   in () end)



   val _ = summarize ()
end

