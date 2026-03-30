import sys
import subprocess
import os

with open('lit-tests/scratch/minimize.ssa.bak', 'r') as f:
    lines = f.readlines()

header_end = 6058 - 1
header = lines[:header_end]

footer_start = -1
for i in range(len(lines) - 1, -1, -1):
    if lines[i].strip() == 'main_4':
        footer_start = i
        break
footer = lines[footer_start:]

funs = []
with open('fun_ranges.txt', 'r') as f:
    for line in f:
        name, start, end = line.split()
        funs.append({'name': name, 'start': int(start)-1, 'end': int(end)})

def write_subset(selected_funs, out_path):
    with open(out_path, 'w') as f:
        f.writelines(header)
        for fun in selected_funs:
            f.writelines(lines[fun['start']:fun['end']])
        f.writelines(footer)

def test(selected_funs):
    write_subset(selected_funs, 'lit-tests/scratch/minimize.ssa')
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

current_funs = funs
print(f"Starting with {len(current_funs)} functions")

# Try to remove functions in chunks
chunk_size = 50
i = 0
while i < len(current_funs):
    chunk = current_funs[i:i+chunk_size]
    # Filter out core functions from the chunk
    filtered_chunk = [f for f in chunk if f['name'] != 'main_4' and f['name'] != 'f_1341']
    if not filtered_chunk:
        i += chunk_size
        continue
    
    test_funs = [f for f in current_funs if f not in filtered_chunk]
    
    print(f"Testing removal of chunk at {i} (size {len(filtered_chunk)})")
    if test(test_funs):
        print(f"Removed chunk at {i}")
        current_funs = test_funs
        # No i += chunk_size
    else:
        if chunk_size == 1:
            i += 1
            chunk_size = 50 # Reset
        else:
            chunk_size //= 2

print(f"Remaining functions: {len(current_funs)}")
write_subset(current_funs, 'lit-tests/scratch/minimize.ssa')
