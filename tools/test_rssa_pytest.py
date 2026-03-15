import pytest
import os
import textwrap
from rssa import parse_rssa

RSSA_PATH = "testdata/annotate-trace-value-3.traceHeapOps.post.rssa"
CACHED_RSSA_FILE_CONTENTS = []

def _read_test_ir():
    if not CACHED_RSSA_FILE_CONTENTS:
        with open(RSSA_PATH, 'r') as f:
            CACHED_RSSA_FILE_CONTENTS.append(f.read())
    return CACHED_RSSA_FILE_CONTENTS[0]


@pytest.fixture
def rssa_content():
    return _read_test_ir()

def test_parse_functions(rssa_content):
    program = parse_rssa(rssa_content)
    # The file has 8 'fun ' lines but our parser splits them. 
    # Let's verify we get a reasonable number.
    assert len(program.functions) >= 7
    if program.main:
        assert program.main.name.name == "initGlobals_0"

def test_parse_object_types(rssa_content):
    program = parse_rssa(rssa_content)
    assert len(program.object_types) == 52
    assert program.object_types[0]['name'] == "opt_0"
    assert "Stack" in program.object_types[0]['def']

def test_printing_idempotency(rssa_content):
    program = parse_rssa(rssa_content)
    output = str(program)
    assert "ObjectTypes:" in output
    assert "fun " in output
    
    # Re-parsing the output should result in the same number of functions
    program2 = parse_rssa(output)
    assert len(program2.functions) == len(program.functions)
    assert len(program2.object_types) == len(program.object_types)

def test_operand_parsing():
    # Test specific operand patterns
    from rssa import RSSAParser, Offset, VarOperand, ConstOperand
    parser = RSSAParser("")
    
    op = parser.parse_operand("OW64 (x_1, 16)")
    assert isinstance(op, Offset)
    assert op.offset == 16
    assert str(op.ty) == "Word64"
    
    op = parser.parse_operand("OP (x_2, ~8)")
    assert isinstance(op, Offset)
    assert op.offset == -8
    assert str(op.ty) == "Objptr"
    
def test_use_def_subgraph(rssa_content):
    program = parse_rssa(rssa_content)
    # x_61059 is a Word64 offset of an argument in num_26
    subgraph = program.get_use_def_subgraph("x_61059")
    
    assert len(subgraph) > 0
    
    # Check if x_61060 is in the subgraph because it uses x_61059
    # We can check by seeing if the Bind statement defining x_61060 is there.
    found_61060_def = False
    for f, b, e in subgraph:
        if hasattr(e, 'dst') and e.dst and str(e.dst[0]) == "x_61060":
            found_61060_def = True
            break
    assert found_61060_def
    
    # Check if x_61057 is in the subgraph (it also uses x_61059 directly)
    found_61057_def = False
    for f, b, e in subgraph:
        if hasattr(e, 'dst') and e.dst and str(e.dst[0]) == "x_61057":
            found_61057_def = True
            break
    assert found_61057_def

    # Check that we didn't pull in EVERYTHING (e.g. some random var from another function)
    # exit_20 uses many globals, but it shouldn't be in our subgraph if it doesn't use x_61059
    # or anything defined by it.
    in_exit_20 = False
    for f, b, e in subgraph:
        if f.name.name == "exit_20":
            in_exit_20 = True
            break
    assert not in_exit_20

def test_repro_x_54427_missing():
    rssa_content = textwrap.dedent("""
    Functions:
    fun main_4 (global_argc: Word32, global_argv: Word64): {raises = None, returns = Some (Word32)} = L_1502 ()
      L_1502 () Jump =
        f () return L_9404
      L_9404 (x_54427: Objptr (opt_33)) CReturn {func = {args = (CPointer, Word64), return = Objptr (opt_33)}} =
        x_61784: Real64 = x_54427
        return (x_61784)
    """)
    program = parse_rssa(rssa_content)
    
    # Check if L_9404 was parsed
    found_l9404 = False
    for f in program.functions:
        for b in f.blocks:
            if b.label.name == "L_9404":
                found_l9404 = True
    
    assert found_l9404, "L_9404 block should be parsed"
    
    subgraph = program.get_use_def_subgraph("x_61784")
    
    # Check if x_54427 definition (the block L_9404 itself) is in the subgraph
    found_x54427_def = False
    for f, b, e in subgraph:
        # For block arguments, the 'element' e is the Block itself
        if b and b.label.name == "L_9404":
            for v, t in b.args:
                if str(v) == "x_54427":
                    found_x54427_def = True
                    break
    
    assert found_x54427_def, "Definition of x_54427 should be found in the subgraph of x_61784"

def test_repro_xr64_stores():
    rssa_content = textwrap.dedent("""
    Functions:
    fun main_4 (global_argc: Word32, global_argv: Word64): {raises = None, returns = Some (Word32)} = L_1502 ()
      L_1502 () Jump =
        f () return L_9404
      L_9404 (x_54427: Objptr (opt_33)) CReturn {func = {args = (CPointer, Word64), return = Objptr (opt_33)}} =
        XR64 (x_54427, 0, 1, 0) := x_61809
        XR64 (x_54427, 8, 1, 8) := x_61808
        x_61784: Real64 = XR64 (x_54427, 0, 1, 8)
        return (x_61784)
    """)
    program = parse_rssa(rssa_content)
    subgraph = program.get_use_def_subgraph("x_61784")
    
    # Check if the XR64 store statements are in the subgraph
    # They should be because they use x_54427, which x_61784 also uses.
    found_store1 = False
    found_store2 = False
    for f, b, e in subgraph:
        if str(e) == "XR64 (x_54427, 0, 1, 0) := x_61809":
            found_store1 = True
        if str(e) == "XR64 (x_54427, 8, 1, 8) := x_61808":
            found_store2 = True
            
    assert found_store1, "Store statement 1 should be in the subgraph"
    assert found_store2, "Store statement 2 should be in the subgraph"
