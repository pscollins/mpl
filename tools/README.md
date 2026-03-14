# RSSA Parser Library

A Python library for parsing and printing MLton/MPL RSSA IR files.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pytest
```

## Running Tests

```bash
PYTHONPATH=tools .venv/bin/pytest tools/test_rssa_pytest.py
```

## Usage

```python
from rssa import parse_rssa

with open("path/to/file.rssa", "r") as f:
    program = parse_rssa(f.read())

# Explore the program structure
for func in program.functions:
    print(f"Function: {func.name}")
    for block in func.blocks:
        print(f"  Block: {block.label}")

# Print back to RSSA format
print(str(program))
```
