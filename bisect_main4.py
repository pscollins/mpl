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
            # Replace body with 'bug'
            rebuilt_main4.append(main4_lines[blocks[i]['start']])
            rebuilt_main4.append("    val _: unit = prim MLton_bug (x_64407 )\n")
            rebuilt_main4.append("    bug\n")
        else:
            rebuilt_main4.extend(main4_lines[blocks[i]['start']:blocks[i]['end']])
    
    new_lines = header + rebuilt_main4 + footer
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.writelines(new_lines)
    
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

print(f"Total blocks in main_4: {len(blocks)}")

removed_indices = set()

# Chunk-based removal
chunk_size = 50
i = 1 # Skip L_0
while i < len(blocks):
    chunk = set(range(i, min(i + chunk_size, len(blocks))))
    # Skip blocks that might be essential (like L_1857 which calls f_1341)
    # Actually, we'll find out if they are essential by testing.
    
    test_set = removed_indices.union(chunk)
    print(f"Testing removal of blocks {min(chunk)} to {max(chunk)}")
    if test_removal_set(test_set):
        print(f"Removed blocks {min(chunk)} to {max(chunk)}")
        removed_indices = test_set
        i += chunk_size
    else:
        if chunk_size > 1:
            chunk_size //= 2
        else:
            i += 1
            chunk_size = 50 # Reset chunk size

print(f"Total blocks removed from main_4: {len(removed_indices)}")
test_removal_set(removed_indices)
