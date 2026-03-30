import sys
import subprocess
import os
import re

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

funs = {}
with open('fun_ranges.txt', 'r') as f:
    for line in f:
        name, start, end = line.split()
        funs[name] = {'start': int(start)-1, 'end': int(end)}

def write_subset(selected_names):
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.writelines(header)
        # Keep original order
        sorted_funs = sorted(funs.items(), key=lambda x: x[1]['start'])
        for name, range_info in sorted_funs:
            if name in selected_names:
                f.writelines(lines[range_info['start']:range_info['end']])
        f.writelines(footer)

def test():
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    if res.returncode == 0:
        return True, None
    return False, res.stderr + res.stdout

necessary_funs = {'main_4', 'f_1341'}
print(f"Starting with {len(necessary_funs)} necessary functions")

while True:
    write_subset(necessary_funs)
    passed, output = test()
    if passed:
        print("PASS! Minimal reproducer found!")
        break
    
    # Look for undefined functions/variables in output
    # MLton error example: "Error: ../minimize.ssa 6075.10-6075.10. Undefined function: zextdFromInt32ToWord32_4"
    match = re.search(r"Undefined function: ([a-zA-Z0-9_\']+)", output)
    if match:
        missing = match.group(1)
        if missing in funs:
            print(f"Adding necessary function: {missing}")
            necessary_funs.add(missing)
            continue
        else:
            print(f"Missing '{missing}' is not a function (maybe a variable?). Cannot easily fix.")
            break
    
    match = re.search(r"Undefined variable: ([a-zA-Z0-9_\']+)", output)
    if match:
        missing = match.group(1)
        print(f"Missing variable: {missing}. This is harder.")
        break
    
    print("Failed to PASS but no obvious missing function found in output.")
    print(output[:1000])
    break

with open('necessary_functions.txt', 'w') as f:
    for n in sorted(list(necessary_funs)):
        f.write(n + '\n')
