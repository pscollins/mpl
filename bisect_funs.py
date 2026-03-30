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

def write_subset(selected_names, out_path):
    with open(out_path, 'w') as f:
        f.writelines(header)
        for fun in funs:
            if fun['name'] in selected_names:
                f.writelines(lines[fun['start']:fun['end']])
        f.writelines(footer)

def test(selected_names):
    write_subset(selected_names, 'lit-tests/scratch/minimize.ssa')
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

current_funs = [f['name'] for f in funs]
print(f"Starting with {len(current_funs)} functions")

# First, try to remove all functions except main_4
if test(['main_4']):
    print("Only main_4 is needed!")
    current_funs = ['main_4']
else:
    print("Need more than just main_4")
    # Trivial greedy removal: try removing each function and see if it still passes
    # But let's do it in chunks first
    chunk_size = 50
    i = 0
    while i < len(current_funs):
        if current_funs[i] == 'main_4':
            i += 1
            continue
        
        chunk = current_funs[i:i+chunk_size]
        remaining = [f for f in current_funs if f not in chunk]
        
        print(f"Testing removal of chunk {i} to {i+len(chunk)}")
        if test(remaining):
            print(f"Removed chunk {i} to {i+len(chunk)}")
            current_funs = remaining
            # Don't increment i because current_funs changed
        else:
            i += chunk_size

# Final pass: one by one
i = 0
while i < len(current_funs):
    if current_funs[i] == 'main_4':
        i += 1
        continue
    
    name = current_funs[i]
    remaining = [f for f in current_funs if f != name]
    
    if test(remaining):
        print(f"Removed function {name}")
        current_funs = remaining
    else:
        i += 1

print(f"Final function count: {len(current_funs)}")
write_subset(current_funs, 'lit-tests/scratch/minimize.ssa')
