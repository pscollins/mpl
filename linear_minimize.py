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

def test_subset(selected_block_indices):
    # This is tricky because we might break control flow.
    # A safer way: try to remove one block at a time by replacing its BODY with 'bug' or something.
    pass

def test_removal(block_idx):
    block = blocks[block_idx]
    if block['name'] == 'L_0': return False # Cannot remove entry block
    
    # Replace block body with 'bug'
    new_block_lines = [main4_lines[block['start']]]
    new_block_lines.append("    val _: unit = prim MLton_bug (x_64407 )\n")
    new_block_lines.append("    bug\n")
    
    new_main4 = main4_lines[:block['start']] + new_block_lines + main4_lines[block['end']:]
    # But wait, this shifts line numbers for subsequent blocks.
    # So we must do it by rebuilding.
    
    # Rebuild main_4
    rebuilt_main4 = []
    for i, b in enumerate(blocks):
        if i == block_idx:
            rebuilt_main4.append(main4_lines[b['start']])
            rebuilt_main4.append("    val _: unit = prim MLton_bug (x_64407 )\n")
            rebuilt_main4.append("    bug\n")
        else:
            rebuilt_main4.extend(main4_lines[b['start']:b['end']])
    
    new_lines = header + rebuilt_main4 + footer
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.writelines(new_lines)
    
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

print(f"Total blocks in main_4: {len(blocks)}")

# Greedy removal
i = 1 # Skip L_0
while i < len(blocks):
    print(f"Testing removal of block {i} ({blocks[i]['name']})")
    if test_removal(i):
        print(f"Removed block {i}")
        # To avoid re-parsing everything, we just update the 'main4_lines' and 'blocks' for next iteration
        # but that's complex. Let's just update a "removed" set.
        pass
    i += 1
