structure Atoms = Atoms ()
structure BackendAtoms = BackendAtoms (open Atoms)
structure Rssa = Rssa (open BackendAtoms)
structure TraceHeapOps = TraceHeapOps (Rssa)

local
   open Rssa

   fun assert (cond, msg) =
      if cond then () else (print ("Assertion failed: " ^ msg ^ "\n"); raise Fail msg)

   val _ = print "Creating empty RSSA program...\n"

   val mainLabel = Label.newNoname ()
   val mainFunc = Func.newNoname ()
   
   val mainBlock = Block.T {
       args = Vector.new0 (),
       kind = Kind.Jump,
       label = mainLabel,
       statements = Vector.new0 (),
       transfer = Transfer.Return (Vector.new0 ())
   }

   val mainFunction = Function.new {
       args = Vector.new0 (),
       blocks = Vector.fromList [mainBlock],
       name = mainFunc,
       raises = NONE,
       returns = SOME (Vector.new0 ()),
       start = mainLabel
   }

   val p = Program.T {
       functions = [],
       handlesSignals = false,
       main = mainFunction,
       objectTypes = Vector.new0 (),
       profileInfo = NONE,
       statics = Vector.new0 ()
   }

   val _ = print "Running TraceHeapOps.transform...\n"
   val p' = TraceHeapOps.transform p

   val Program.T {functions, main, ...} = p'
   val _ = assert (List.length functions = 0, "functions list should be empty")
   val _ = assert (Func.equals (Function.name main, mainFunc), "main function name should match")

   val _ = print "TraceHeapOps tests passed.\n"
in
end
