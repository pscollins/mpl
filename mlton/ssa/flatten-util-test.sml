local
   open Ssa
in
   val _ = let
      val _ = print "Testing FlattenUtil...\n"
      
      val f1Name = Func.fromString "f1"
      val f1Label = Label.fromString "L1"
      val f1Label2 = Label.fromString "L1_2"
      val f1Block = Block.T {
         args = Vector.new0 (),
         label = f1Label,
         statements = Vector.new0 (),
         transfer = Transfer.Goto {args = Vector.new0 (), dst = f1Label2}
      }
      val f1Block2 = Block.T {
         args = Vector.new0 (),
         label = f1Label2,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f1Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f1Block, f1Block2],
         inline = InlineAttr.Auto,
         name = f1Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f1Label
      }

      val f2Name = Func.fromString "f2"
      val f2Label = Label.fromString "L2"
      val f2Block = Block.T {
         args = Vector.new0 (),
         label = f2Label,
         statements = Vector.new0 (),
         transfer = Transfer.Return (Vector.new0 ())
      }
      val f2Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f2Block],
         inline = InlineAttr.Auto,
         name = f2Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f2Label
      }

      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [f1Function, f2Function],
         globals = Vector.new0 (),
         main = f1Name
      }

      val _ = print "Test: foreachFunction\n"
      val seen = ref []
      val _ = FlattenUtil.foreachFunction (p, fn f => seen := Function.name f :: !seen)
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f1Name)), "f1 not seen")
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f2Name)), "f2 not seen")
      val _ = assert (List.length (!seen) = 2, "Wrong number of functions seen")

      val _ = print "Test: newFuncsMap\n"
      val {getFunc, getBlock, destroyFuncsMap} = FlattenUtil.newFuncsMap p
      
      val _ = assert (Func.equals (Function.name (getFunc f1Name), f1Name), "getFunc f1 failed")
      val _ = assert (Func.equals (Function.name (getFunc f2Name), f2Name), "getFunc f2 failed")
      
      val _ = assert (Label.equals (Block.label (getBlock f1Label), f1Label), "getBlock f1Label failed")
      val _ = assert (Label.equals (Block.label (getBlock f1Label2), f1Label2), "getBlock f1Label2 failed")
      val _ = assert (Label.equals (Block.label (getBlock f2Label), f2Label), "getBlock f2Label failed")
      
      val _ = destroyFuncsMap()
      val _ = print "FlattenUtil tests passed\n"
   in () end
end
