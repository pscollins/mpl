import sys
import re
import subprocess

with open('lit-tests/scratch/minimize.ssa.bak', 'r') as f:
    lines = f.readlines()

main4_start = 6058 - 1
main4_end = 13004

header = lines[:main4_start]
main4_lines = lines[main4_start:main4_end]
footer = lines[main4_end:]

# Find blocks
block_re = re.compile(r'^\s+block (L_\d+) \((.*?)\)')
blocks = []
current_block = None
for i, line in enumerate(main4_lines):
    match = block_re.match(line)
    if match:
        if current_block:
            current_block['end'] = i
            blocks.append(current_block)
        current_block = {'name': match.group(1), 'args': match.group(2), 'start': i}

if current_block:
    current_block['end'] = len(main4_lines)
    blocks.append(current_block)

def test_removal_set(to_remove_indices):
    rebuilt_main4 = []
    # Always keep L_0
    rebuilt_main4.extend(main4_lines[blocks[0]['start']:blocks[0]['end']])
    
    for i in range(1, len(blocks)):
        if i in to_remove_indices:
            # Replace body with 'return (())'
            rebuilt_main4.append(main4_lines[blocks[i]['start']])
            rebuilt_main4.append("    return (x_76660 )\n")
        else:
            rebuilt_main4.extend(main4_lines[blocks[i]['start']:blocks[i]['end']])
    
    new_lines = header + rebuilt_main4 + footer
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.writelines(new_lines)
    
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

removed = set()
chunk_size = 100
i = 1
while i < len(blocks):
    chunk = set(range(i, min(i + chunk_size, len(blocks))))
    print(f"Testing removal of {len(chunk)} blocks starting at {i}")
    if test_removal_set(removed.union(chunk)):
        print(f"Removed {len(chunk)} blocks")
        removed.update(chunk)
        i += chunk_size
    else:
        if chunk_size > 1:
            chunk_size //= 2
        else:
            i += 1
            chunk_size = 100

print(f"Total blocks removed: {len(removed)}")
test_removal_set(removed)
