structure Atoms = Atoms ()
structure Ssa2 = Ssa2 (open Atoms)
structure RewriteSsa2 = RewriteSsa2 (Ssa2)

open RewriteSsa2

val _ = print "Running RewriteSsa2 tests...\n"

fun assert (msg, f) =
    if f () then ()
    else (print ("Assertion failed: " ^ msg ^ "\n");
          OS.Process.exit OS.Process.failure)

local
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val s0 = VarSet.empty
   val s1 = VarSet.singleton v1
   val s2 = VarSet.add (s1, v2)
in
   val _ = assert ("s0 empty", fn () => VarSet.isEmpty s0)
   val _ = assert ("s1 has v1", fn () => VarSet.contains (s1, v1))
   val _ = assert ("s1 not has v2", fn () => not (VarSet.contains (s1, v2)))
   val _ = assert ("s2 has v1", fn () => VarSet.contains (s2, v1))
   val _ = assert ("s2 has v2", fn () => VarSet.contains (s2, v2))
   val _ = assert ("s2 size 2", fn () => VarSet.size s2 = 2)
end

local
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val t = Type.unit
   val stmt = Statement.Bind {exp = Exp.Var v1, ty = t, var = SOME v2}
in
   val _ = assert ("extractUses bind has v1", fn () => VarSet.contains (extractUses stmt, v1))
   val _ = assert ("extractDefs bind has v2", fn () => VarSet.contains (extractDefs stmt, v2))
   val _ = assert ("getDefIndex find v2", fn () => getDefIndex (Vector.fromList [stmt], v2) = SOME 0)
end

local
   val v_base = Var.newNoname ()
   val v_val = Var.newNoname ()
   val stmt = Statement.Update {base = Base.Object v_base, offset = 0, value = v_val, writeBarrier = false}
in
   val _ = assert ("extractUses update has v_base", fn () => VarSet.contains (extractUses stmt, v_base))
   val _ = assert ("extractUses update has v_val", fn () => VarSet.contains (extractUses stmt, v_val))
   val _ = assert ("extractDefs update is empty", fn () => VarSet.isEmpty (extractDefs stmt))
end

local
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val v3 = Var.newNoname ()
   val stmt = Statement.Bind {exp = Exp.Object {args = Vector.fromList [v1, v2], con = NONE},
                              ty = Type.unit,
                              var = SOME v3}
in
   val _ = assert ("extractUses object has v1", fn () => VarSet.contains (extractUses stmt, v1))
   val _ = assert ("extractUses object has v2", fn () => VarSet.contains (extractUses stmt, v2))
   val _ = assert ("extractDefs object has v3", fn () => VarSet.contains (extractDefs stmt, v3))
end

local
   val {graph, getNode, getVar} = UseDefGraph.new ()
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val n1 = getNode v1
   val n2 = getNode v2
in
   val _ = assert ("getVar n1 is v1", fn () => Var.equals (getVar n1, v1))
   val _ = assert ("getVar n2 is v2", fn () => Var.equals (getVar n2, v2))
   val _ = assert ("n1 and n2 are different", fn () => not (DirectedGraph.Node.equals (n1, n2)))
   val _ = assert ("getNode v1 is idempotent", fn () => DirectedGraph.Node.equals (getNode v1, n1))

   val _ = UseDefGraph.addEdge {graph = graph, getNode = getNode, getVar = getVar} (v1, v2)
   val _ = assert ("edge v1 -> v2 added", fn () => DirectedGraph.Node.hasEdge {from = n1, to = n2})
   val _ = assert ("edge v2 -> v1 added", fn () => DirectedGraph.Node.hasEdge {from = n2, to = n1})
end

local
   val g = UseDefGraph.new ()
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val v3 = Var.newNoname ()
   val _ = UseDefGraph.addEdge g (v1, v2)
   val _ = UseDefGraph.addEdge g (v2, v3)
   val reachable = UseDefGraph.findReachable (g, v1)
in
   val _ = assert ("findReachable contains v1", fn () => VarSet.contains (reachable, v1))
   val _ = assert ("findReachable contains v2", fn () => VarSet.contains (reachable, v2))
   val _ = assert ("findReachable contains v3", fn () => VarSet.contains (reachable, v3))
end

local
   val g = UseDefGraph.new ()
   val v1 = Var.newNoname ()
   val v2 = Var.newNoname ()
   val v3 = Var.newNoname ()
   val v4 = Var.newNoname ()
   val _ = UseDefGraph.addEdge g (v1, v2)
   val _ = UseDefGraph.addEdge g (v1, v3)
   val _ = UseDefGraph.addEdge g (v3, v4)
   val reachable = UseDefGraph.findReachable (g, v1)
in
   val _ = assert ("v4 is reachable from v1", fn () => VarSet.contains (reachable, v4))
end

local
   (* Helpers for building programs *)
   fun makeProgram {datatypes, functions, globals, main} =
      Program.T {datatypes = Vector.fromList datatypes,
                 functions = functions,
                 globals = Vector.fromList globals,
                 main = main}

   fun makeFunction {name, args, start, blocks, returns} =
      Function.new {name = name,
                    args = Vector.fromList args,
                    start = start,
                    blocks = Vector.fromList blocks,
                    returns = SOME (Vector.fromList returns),
                    raises = NONE,
                    inline = InlineAttr.Auto}

   fun makeBlock {label, args, statements, transfer} =
      Block.T {label = label,
               args = Vector.fromList args,
               statements = Vector.fromList statements,
               transfer = transfer}

   val unitTy = Type.unit
in

   (* Test Rule 1: Bind (v2 = exp(v1)) *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val stmt = Statement.Bind {exp = Exp.Var v1, ty = unitTy, var = SOME v2}
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val g = UseDefGraph.fromProgram prog
   in
      assert ("Rule 1: Bind v2 = exp(v1) implies v1 <-> v2",
              fn () => VarSet.contains (UseDefGraph.findReachable (g, v1), v2))
   end

   (* Test Rule 2: Update (v1.offset = v2) *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val stmt = Statement.Update {base = Base.Object v1, offset = 0, value = v2, writeBarrier = false}
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val g = UseDefGraph.fromProgram prog
   in
      assert ("Rule 2: Update v1.offset = v2 implies v1 <-> v2",
              fn () => VarSet.contains (UseDefGraph.findReachable (g, v1), v2))
   end

   (* Test Rule 3: Function arguments (fun f(v1); call f(v2)) *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val fName = Func.newNoname ()
      val fStart = Label.newNoname ()
      val fBlock = makeBlock {label = fStart, args = [], statements = [],
                              transfer = Transfer.Return (Vector.new0 ())}
      val fFunc = makeFunction {name = fName, args = [(v1, unitTy)], start = fStart,
                                blocks = [fBlock], returns = []}

      val mainFunc = Func.newNoname ()
      val mainStart = Label.newNoname ()
      val mainBlock = makeBlock {label = mainStart, args = [], statements = [],
                                 transfer = Transfer.Call {args = Vector.fromList [v2],
                                                           func = fName,
                                                           inline = InlineAttr.Auto,
                                                           return = Return.Tail}}
      val mainFuncObj = makeFunction {name = mainFunc, args = [], start = mainStart,
                                      blocks = [mainBlock], returns = []}

      val prog = makeProgram {datatypes = [], functions = [fFunc, mainFuncObj],
                              globals = [], main = mainFunc}
      val g = UseDefGraph.fromProgram prog
   in
      assert ("Rule 3: fun f(v1) called with f(v2) implies v1 <-> v2",
              fn () => VarSet.contains (UseDefGraph.findReachable (g, v1), v2))
   end

   (* Test Rule 4: Block arguments (L(v1); goto L(v2)) *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val nextLabel = Label.newNoname ()
      val startBlock = makeBlock {label = startLabel, args = [], statements = [],
                                  transfer = Transfer.Goto {args = Vector.fromList [v2],
                                                            dst = nextLabel}}
      val nextBlock = makeBlock {label = nextLabel, args = [(v1, unitTy)], statements = [],
                                 transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [startBlock, nextBlock], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val g = UseDefGraph.fromProgram prog
   in
      assert ("Rule 4: Label L(v1) called with goto L(v2) implies v1 <-> v2",
              fn () => VarSet.contains (UseDefGraph.findReachable (g, v1), v2))
   end

   (* Test Rule 5: Return relationship (fun f() returns (v1); call f() returns to L(v2)) *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val fName = Func.newNoname ()
      val fStart = Label.newNoname ()
      val fBlock = makeBlock {label = fStart, args = [], statements = [],
                              transfer = Transfer.Return (Vector.fromList [v1])}
      val fFunc = makeFunction {name = fName, args = [], start = fStart,
                                blocks = [fBlock], returns = [unitTy]}

      val mainFunc = Func.newNoname ()
      val mainStart = Label.newNoname ()
      val contLabel = Label.newNoname ()
      val mainBlock = makeBlock {label = mainStart, args = [], statements = [],
                                 transfer = Transfer.Call {args = Vector.new0 (),
                                                           func = fName,
                                                           inline = InlineAttr.Auto,
                                                           return = Return.NonTail {cont = contLabel,
                                                                                    handler = Handler.Caller}}}
      val contBlock = makeBlock {label = contLabel, args = [(v2, unitTy)], statements = [],
                                 transfer = Transfer.Return (Vector.new0 ())}
      val mainFuncObj = makeFunction {name = mainFunc, args = [], start = mainStart,
                                      blocks = [mainBlock, contBlock], returns = []}

      val prog = makeProgram {datatypes = [], functions = [fFunc, mainFuncObj],
                              globals = [], main = mainFunc}
      val g = UseDefGraph.fromProgram prog
   in
      assert ("Rule 5: fun f() return(v1) called with cont L(v2) implies v1 <-> v2",
              fn () => VarSet.contains (UseDefGraph.findReachable (g, v1), v2))
   end

   (* Test Case 6: Transitivity (v1 <-> v2 <-> v3) *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val v3 = Var.newNoname ()
      val stmt1 = Statement.Bind {exp = Exp.Var v1, ty = unitTy, var = SOME v2}
      val stmt2 = Statement.Bind {exp = Exp.Var v2, ty = unitTy, var = SOME v3}
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt1, stmt2],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val g = UseDefGraph.fromProgram prog
   in
      assert ("Transitivity: v1 <-> v2 <-> v3 implies v1 <-> v3",
              fn () => VarSet.contains (UseDefGraph.findReachable (g, v1), v3))
   end

   (* trimProgram Test Case 1: Empty program stays empty *)
   val _ = let
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val trimmed = trimProgram (prog, VarSet.empty)
      val Program.T {functions, ...} = trimmed
      val func0 = List.nth (functions, 0)
      val Block.T {statements, ...} = Vector.sub (Function.blocks func0, 0)
   in
      assert ("trimProgram Case 1: Empty program stays empty",
              fn () => Vector.length statements = 0)
   end

   (* trimProgram Test Case 2: Statement is NOT deleted if it refers to a watched variable *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val stmt = Statement.Bind {exp = Exp.Var v1, ty = unitTy, var = SOME v2}
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val trimmed = trimProgram (prog, VarSet.singleton v1)
      val Program.T {functions, ...} = trimmed
      val func0 = List.nth (functions, 0)
      val Block.T {statements, ...} = Vector.sub (Function.blocks func0, 0)
   in
      assert ("trimProgram Case 2: Statement NOT deleted if it refers to v1 (in exp)",
              fn () => Vector.length statements = 1)
   end

   (* trimProgram Test Case 3: Statement IS deleted if it does NOT refer to any watched variable *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val stmt = Statement.Bind {exp = Exp.Var v1, ty = unitTy, var = SOME v2}
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val v3 = Var.newNoname ()
      val trimmed = trimProgram (prog, VarSet.singleton v3)
      val Program.T {functions, ...} = trimmed
      val func0 = List.nth (functions, 0)
      val Block.T {statements, ...} = Vector.sub (Function.blocks func0, 0)
   in
      assert ("trimProgram Case 3: Statement IS deleted if it doesn't refer to v3",
              fn () => Vector.length statements = 0)
   end

   (* trimProgram Test Case 4: Globals are trimmed *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val stmt = Statement.Bind {exp = Exp.Var v1, ty = unitTy, var = SOME v2}
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [stmt], main = mainFunc}
      val v3 = Var.newNoname ()
      val trimmed = trimProgram (prog, VarSet.singleton v3)
      val Program.T {globals, ...} = trimmed
   in
      assert ("trimProgram Case 4: Global IS deleted if it doesn't refer to v3",
              fn () => Vector.length globals = 0)
   end

   (* trimProgram Test Case 5: Mix of kept and deleted statements *)
   val _ = let
      val v1 = Var.newNoname ()
      val v2 = Var.newNoname ()
      val v3 = Var.newNoname ()
      val v4 = Var.newNoname ()
      val stmt1 = Statement.Bind {exp = Exp.Var v1, ty = unitTy, var = SOME v2}
      val stmt2 = Statement.Bind {exp = Exp.Var v3, ty = unitTy, var = SOME v4}
      val mainFunc = Func.newNoname ()
      val startLabel = Label.newNoname ()
      val block = makeBlock {label = startLabel, args = [], statements = [stmt1, stmt2],
                             transfer = Transfer.Return (Vector.new0 ())}
      val func = makeFunction {name = mainFunc, args = [], start = startLabel,
                               blocks = [block], returns = []}
      val prog = makeProgram {datatypes = [], functions = [func], globals = [], main = mainFunc}
      val trimmed = trimProgram (prog, VarSet.singleton v1)
      val Program.T {functions, ...} = trimmed
      val func0 = List.nth (functions, 0)
      val Block.T {statements, ...} = Vector.sub (Function.blocks func0, 0)
   in
      assert ("trimProgram Case 5: stmt1 kept, stmt2 deleted",
              fn () => Vector.length statements = 1)
   end

end

val _ = print "All RewriteSsa2 tests passed!\n"
