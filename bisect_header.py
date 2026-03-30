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

# Try to remove chunks from the end
chunk_size = 50
while True:
    if len(current_funs) <= 2:
        break
    
    test_funs = current_funs[:-chunk_size]
    # Ensure main_4 and f_1341 are still there
    has_main4 = any(f['name'] == 'main_4' for f in test_funs)
    has_f1341 = any(f['name'] == 'f_1341' for f in test_funs)
    
    if not (has_main4 and has_f1341):
        if chunk_size == 1:
            break
        chunk_size //= 2
        continue

    print(f"Testing removal of last {chunk_size} functions")
    if test(test_funs):
        print(f"Removed last {chunk_size} functions")
        current_funs = test_funs
    else:
        if chunk_size == 1:
            break
        chunk_size //= 2

print(f"Remaining functions: {len(current_funs)}")
write_subset(current_funs, 'lit-tests/scratch/minimize.ssa')
