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

      val f3Name = Func.fromString "f3"
      val f3Label = Label.fromString "L3"
      val f3Label2 = Label.fromString "L3_2"
      val f3Block = Block.T {
         args = Vector.new0 (),
         label = f3Label,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.new0 (),
            func = f1Name,
            inline = InlineAttr.Auto,
            return = Return.NonTail {cont = f3Label2, handler = Handler.Caller}
         }
      }
      val f3Block2 = Block.T {
         args = Vector.new0 (),
         label = f3Label2,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.new0 (),
            func = f2Name,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val f3Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f3Block, f3Block2],
         inline = InlineAttr.Auto,
         name = f3Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f3Label
      }

      val f4Name = Func.fromString "f4"
      val f4Label = Label.fromString "L4"
      val f4Block = Block.T {
         args = Vector.new0 (),
         label = f4Label,
         statements = Vector.new0 (),
         transfer = Transfer.Call {
            args = Vector.new0 (),
            func = f4Name,
            inline = InlineAttr.Auto,
            return = Return.Tail
         }
      }
      val f4Function = Function.new {
         args = Vector.new0 (),
         blocks = Vector.fromList [f4Block],
         inline = InlineAttr.Auto,
         name = f4Name,
         raises = NONE,
         returns = SOME (Vector.new0 ()),
         start = f4Label
      }

      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [f1Function, f2Function, f3Function, f4Function],
         globals = Vector.new0 (),
         main = f1Name
      }

      val _ = print "Test: foreachFunction\n"
      val seen = ref []
      val _ = FlattenUtil.foreachFunction (p, fn f => seen := Function.name f :: !seen)
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f1Name)), "f1 not seen")
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f2Name)), "f2 not seen")
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f3Name)), "f3 not seen")
      val _ = assert (List.exists (!seen, fn n => Func.equals (n, f4Name)), "f4 not seen")
      val _ = assert (List.length (!seen) = 4, "Wrong number of functions seen")

      val _ = print "Test: newFuncsMap\n"
      val {getFunc, getBlock, getCallees, destroyFuncsMap} = FlattenUtil.newFuncsMap p
      
      val _ = assert (Func.equals (Function.name (getFunc f1Name), f1Name), "getFunc f1 failed")
      val _ = assert (Func.equals (Function.name (getFunc f2Name), f2Name), "getFunc f2 failed")
      
      val _ = assert (Label.equals (Block.label (getBlock f1Label), f1Label), "getBlock f1Label failed")
      val _ = assert (Label.equals (Block.label (getBlock f1Label2), f1Label2), "getBlock f1Label2 failed")
      val _ = assert (Label.equals (Block.label (getBlock f2Label), f2Label), "getBlock f2Label failed")

      val _ = print "Test: getCallees\n"
      fun hasCallee (callees, name) = Vector.exists (callees, fn n => Func.equals (n, name))
      
      val f1Callees = getCallees f1Name
      val _ = assert (Vector.length f1Callees = 0, "f1 should have no callees")
      
      val f2Callees = getCallees f2Name
      val _ = assert (Vector.length f2Callees = 0, "f2 should have no callees")
      
      val f3Callees = getCallees f3Name
      val _ = assert (hasCallee (f3Callees, f1Name), "f3 should call f1")
      val _ = assert (hasCallee (f3Callees, f2Name), "f3 should call f2")
      val _ = assert (Vector.length f3Callees = 2, "f3 should have 2 callees")
      
      val f4Callees = getCallees f4Name
      val _ = assert (hasCallee (f4Callees, f4Name), "f4 should call f4")
      val _ = assert (Vector.length f4Callees = 1, "f4 should have 1 callee")
      
      val _ = destroyFuncsMap()
      val _ = print "FlattenUtil tests passed\n"
   in () end
end
