import sys
import re
import subprocess

with open('lit-tests/scratch/minimize.ssa.bak', 'r') as f:
    lines = f.readlines()

main4_start = 6058 - 1
main4_end = 13004

main4_lines = lines[main4_start:main4_end]

# Find blocks
block_re = re.compile(r'^\s+block (L_\d+) \((.*?)\)')
blocks = []
for i, line in enumerate(main4_lines):
    match = block_re.match(line)
    if match:
        blocks.append({'name': match.group(1), 'args': match.group(2), 'line': i})

def test_truncation(block_idx):
    block = blocks[block_idx]
    # We'll replace this block with a 'bug' or 'return'
    # Actually, we should probably just return the correct type.
    # main_4 returns (unit)
    new_main4 = main4_lines[:block['line'] + 1]
    new_main4.append(f"    val _: unit = prim MLton_bug (x_64407 )\n")
    new_main4.append(f"    bug\n")
    
    new_lines = lines[:main4_start] + new_main4 + lines[main4_end:]
    
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.writelines(new_lines)
    
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

print(f"Total blocks in main_4: {len(blocks)}")

# Binary search for the earliest block that still reproduces the bug
low = 0
high = len(blocks) - 1
best = high

while low <= high:
    mid = (low + high) // 2
    print(f"Testing truncation at block {mid} ({blocks[mid]['name']})")
    if test_truncation(mid):
        print(f"Truncation at {mid} SUCCEEDED")
        best = mid
        high = mid - 1
    else:
        print(f"Truncation at {mid} FAILED")
        low = mid + 1

print(f"Best truncation block: {best} ({blocks[best]['name']})")
test_truncation(best)
