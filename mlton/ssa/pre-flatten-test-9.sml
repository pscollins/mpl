local
   open Ssa
in
   (* Test 57: transform with preFlattenLevelSteps = [Function] *)
   val _ = let
      val _ = print "Test 57: transform with preFlattenLevelSteps = [Function]\n"
      val mainFunc = Func.fromString "main57"
      val mainLabel = Label.fromString "L57"
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }

      val _ = Control.preFlattenLevelSteps := [Control.PreFlattenLevelStep.Function]
      val _ = PreFlatten.transform p
      val _ = print "Test 57 passed\n"
   in () end

   (* Test 58: transform with preFlattenLevelSteps = [Block] *)
   val _ = let
      val _ = print "Test 58: transform with preFlattenLevelSteps = [Block]\n"
      val mainFunc = Func.fromString "main58"
      val mainLabel = Label.fromString "L58"
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }

      val _ = Control.preFlattenLevelSteps := [Control.PreFlattenLevelStep.Block]
      val _ = PreFlatten.transform p
      val _ = print "Test 58 passed\n"
   in () end

   (* Test 59: transform with preFlattenLevelSteps = [Function, Block] *)
   val _ = let
      val _ = print "Test 59: transform with preFlattenLevelSteps = [Function, Block]\n"
      val mainFunc = Func.fromString "main59"
      val mainLabel = Label.fromString "L59"
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }

      val _ = Control.preFlattenLevelSteps := [Control.PreFlattenLevelStep.Function, Control.PreFlattenLevelStep.Block]
      val _ = PreFlatten.transform p
      val _ = print "Test 59 passed\n"
   in () end
end
