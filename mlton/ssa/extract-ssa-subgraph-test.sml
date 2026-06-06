structure Atoms = Atoms ()
structure Ssa = Ssa (open Atoms)
structure ExtractSsaSubgraph = ExtractSsaSubgraph (Ssa)

local
   open Ssa
in
   val _ = runTest ("Test 1: no-op transform", fn () => let
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
      val p = Program.T {
         datatypes = Vector.new0 (),
         functions = [mainFunction],
         globals = Vector.new0 (),
         main = mainFunc
      }
      val p' = ExtractSsaSubgraph.transform p
      val Program.T {main, ...} = p'
   in
      if Func.toString main = "main" then ()
      else raise TestFail "Program main function changed"
   end)

   val _ = summarize ()
end
