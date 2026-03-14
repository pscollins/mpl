from tools.rssa import parse_rssa, PrimApp, Bind, CCall, Goto, Label, Func

content = """
Functions:
fun test_func (arg1: Word64): {raises = None, returns = None} = L1 ()
  L1 () Jump =
    _: Bits0 = Trace_staticSourceMarkValue:px1 (x_61784)
    y_1: Word64 = Word64_add:px1 (arg1, 1:w64)
    ccall C_Func:v (y_1) return L2
  L2 () Jump =
    TailCall_target:px1 (y_1) Tail
"""

program = parse_rssa(content)
func = program.functions[0]
block1 = func.blocks[0]
block2 = func.blocks[1]

print("Block L1:")
for i, stmt in enumerate(block1.statements):
    print(f"Stmt {i} type: {type(stmt)}")
    print(f"Stmt {i} string: {stmt}")
    if isinstance(stmt, PrimApp):
        print(f"  Prim: {stmt.prim}, Args: {[str(a) for a in stmt.args]}")
    elif isinstance(stmt, Bind):
        print(f"  Src: {stmt.src}")

print(f"Transfer type: {type(block1.transfer)}")
print(f"Transfer string: {block1.transfer}")
if isinstance(block1.transfer, CCall):
    print(f"  Func: {block1.transfer.func}, Return: {block1.transfer.return_label}")

print("\nBlock L2:")
print(f"Transfer type: {type(block2.transfer)}")
print(f"Transfer string: {block2.transfer}")

subgraph = program.get_use_def_subgraph("x_61784")
print("\nSubgraph elements for x_61784:")
for f, b, e in subgraph:
    print(f"Element: {e}")

subgraph2 = program.get_use_def_subgraph("arg1")
print("\nSubgraph elements for arg1:")
for f, b, e in subgraph2:
    print(f"Element: {e}")
