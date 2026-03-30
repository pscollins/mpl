import re
import sys

with open('lit-tests/scratch/minimize.ssa', 'r') as f:
    lines = f.readlines()

funs = []
current_fun = None

fun_start_re = re.compile(r'^fun (?:(?:__inline_never__ |__inline_always__ )*)?([a-zA-Z0-9_\']+)')

for i, line in enumerate(lines):
    match = fun_start_re.match(line)
    if match:
        if current_fun:
            current_fun['end'] = i
            funs.append(current_fun)
        current_fun = {'name': match.group(1), 'start': i + 1}

# The functions end when the main entry point is reached or end of file
# Let's find where " main_4 " is at the end
last_line_idx = len(lines)
for i in range(len(lines) - 1, -1, -1):
    if lines[i].strip() == 'main_4':
        last_line_idx = i
        break

if current_fun:
    current_fun['end'] = last_line_idx
    funs.append(current_fun)

with open('fun_ranges.txt', 'w') as f:
    for fun in funs:
        f.write(f"{fun['name']} {fun['start']} {fun['end']}\n")
