structure Atoms = Atoms ()
structure Ssa = SsaTree (open Atoms)
structure ParseSsa = ParseSsa (Ssa)

local
   open Ssa

   fun assert (cond, msg) =
      if cond then () else (print ("Assertion failed: " ^ msg ^ "\n"); OS.Process.exit OS.Process.failure)

   fun layoutToString p =
      let
         val lts = ref []
         val _ = Program.layouts (p, fn l => lts := l :: !lts)
      in
         Layout.toString (Layout.align (List.rev (!lts)))
      end

   fun assertEqual (s1, s1', msg) =
      if s1 = s1' then () 
      else (print (msg ^ "\n"); 
            print "Expected:\n"; print s1; print "\n";
            print "Actual:\n"; print s1'; print "\n";
            OS.Process.exit OS.Process.failure)

   val _ = print "Running ParseSsa tests...\n"

   (* Test 1: Simple program round-trip *)
   val _ = let
      val _ = print "Test 1: Simple program round-trip\n"
      val mainFunc = Func.fromString "main"
      val mainLabel = Label.fromString "L0"
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
      }
      val p1 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val s1 = layoutToString p1
      val _ = (print "Layout for Test 1:\n"; print s1; print "\n")
      val p1' = ParseSsa.parseString s1
      val s1' = layoutToString p1'
      
      val _ = assertEqual (s1, s1', "Round-trip layout mismatch in Test 1")
      val _ = print "Test 1 passed\n"
   in () end

   (* Test 2: Program with statements *)
   val _ = let
      val _ = print "Test 2: Program with statements\n"
      val mainFunc = Func.fromString "main2"
      val mainLabel = Label.fromString "L1"
      
      val var1 = Var.fromString "v1"
      val ty1 = Type.intInf
      
      val stmt1 = Statement.T {
         exp = Exp.Const (Const.IntInf 42),
         ty = ty1,
         var = SOME var1
      }
      
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.fromList [stmt1],
         transfer = Transfer.Return (Vector.fromList [var1])
      }
      
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.fromList [ty1]),
         start = mainLabel
      }
      
      val p2 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val s2 = layoutToString p2
      val _ = (print "Layout for Test 2:\n"; print s2; print "\n")
      val p2' = ParseSsa.parseString s2
      val s2' = layoutToString p2'
      
      val _ = assertEqual (s2, s2', "Round-trip layout mismatch in Test 2")
      val _ = print "Test 2 passed\n"
   in () end

   (* Test 3: Program with datatypes *)
   val _ = let
      val _ = print "Test 3: Program with datatypes\n"
      val mainFunc = Func.fromString "main3"
      val mainLabel = Label.fromString "L2"
      
      val tycon = Tycon.fromString "list"
      val conNil = Con.fromString "Nil"
      val conCons = Con.fromString "Cons"
      
      val dt = Datatype.T {
         cons = Vector.fromList [
            {args = Vector.new0 (), con = conNil},
            {args = Vector.fromList [Type.intInf, Type.datatypee tycon], con = conCons}
         ],
         tycon = tycon
      }
      
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
      }
      
      val p3 = Program.T {
         datatypes = Vector.fromList [dt],
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      
      val s3 = layoutToString p3
      val _ = (print "Layout for Test 3:\n"; print s3; print "\n")
      val p3' = ParseSsa.parseString s3
      val s3' = layoutToString p3'
      
      val _ = assertEqual (s3, s3', "Round-trip layout mismatch in Test 3")
      val _ = print "Test 3 passed\n"
   in () end

   (* Test 4: Program with globals *)
   val _ = let
      val _ = print "Test 4: Program with globals\n"
      val mainFunc = Func.fromString "main4"
      val mainLabel = Label.fromString "L3"
      
      val varG = Var.fromString "g1"
      val tyG = Type.word WordSize.word64
      
      val global1 = Statement.T {
         exp = Exp.Const (Const.Word (WordX.fromInt (123, WordSize.word64))),
         ty = tyG,
         var = SOME varG
      }
      
      val mainBlock = Block.T {
         args = Vector.new0 (),
         label = mainLabel,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      
      val mainFunction = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [mainBlock],
         inline = InlineAttr.Auto,
         name = mainFunc,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = mainLabel
      }
      
      val p4 = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.fromList [global1],
         main = mainFunc
      }
      
      val s4 = layoutToString p4
      val _ = (print "Layout for Test 4:\n"; print s4; print "\n")
      val p4' = ParseSsa.parseString s4
      val s4' = layoutToString p4'
      
      val _ = assertEqual (s4, s4', "Round-trip layout mismatch in Test 4")
      val _ = print "Test 4 passed\n"
   in () end
in
end
