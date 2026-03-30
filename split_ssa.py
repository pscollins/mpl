import sys
import os

with open('lit-tests/scratch/minimize.ssa', 'r') as f:
    lines = f.readlines()

header_end = 6058 - 1 # main_4 starts at 6058
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

# Initial test: write all functions
write_subset([f['name'] for f in funs], 'lit-tests/scratch/test_all.ssa')
