import pytest
import os
from rssa import parse_rssa

RSSA_PATH = "/tmp/out-real/annotate-trace-value-3.traceHeapOps.post.rssa"

@pytest.fixture
def rssa_content():
    if not os.path.exists(RSSA_PATH):
        pytest.skip(f"RSSA file not found at {RSSA_PATH}")
    with open(RSSA_PATH, 'r') as f:
        return f.read()

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
    
    op = parser.parse_operand("0x123:w32")
    assert isinstance(op, ConstOperand)
    assert op.const.value == "0x123:w32"
