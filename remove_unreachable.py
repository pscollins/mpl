import sys
import re

with open('fun_ranges.txt', 'r') as f:
    funs = {}
    for line in f:
        name, start, end = line.split()
        funs[name] = {'start': int(start)-1, 'end': int(end)}

with open('lit-tests/scratch/minimize.ssa.bak', 'r') as f:
    lines = f.readlines()

fun_names = set(funs.keys())

# Map from function name to set of called function names
calls = {}
for name, range_info in funs.items():
    body = "".join(lines[range_info['start']:range_info['end']])
    called = set()
    # Simple regex to find called functions.
    # We look for the word followed by '(' but only if it's in our fun_names set.
    # This might have some false positives if a variable has the same name as a function,
    # but in MLton SSA, function names are usually distinct.
    # Find all words that match a function name.
    # We use \b to ensure we match whole words.
    for f in fun_names:
        if f != name and re.search(r'\b' + re.escape(f) + r'\b', body):
            called.add(f)
    calls[name] = called

reachable = set()
to_visit = ['main_4']
while to_visit:
    curr = to_visit.pop()
    if curr not in reachable:
        reachable.add(curr)
        if curr in calls:
            for neighbor in calls[curr]:
                if neighbor not in reachable:
                    to_visit.append(neighbor)

print(f"Total functions: {len(fun_names)}")
print(f"Reachable functions: {len(reachable)}")

header_end = 6058 - 1
header = lines[:header_end]
footer_start = -1
for i in range(len(lines) - 1, -1, -1):
    if lines[i].strip() == 'main_4':
        footer_start = i
        break
footer = lines[footer_start:]

with open('lit-tests/scratch/minimize.ssa', 'w') as f:
    f.writelines(header)
    # Important: keep functions in their original order
    for i, line in enumerate(lines):
        # This is a bit slow but safe.
        # Alternatively, use our funs ranges.
        pass
    
    # Let's use funs ranges but only if they are reachable
    sorted_funs = sorted(funs.items(), key=lambda x: x[1]['start'])
    for name, range_info in sorted_funs:
        if name in reachable:
            f.writelines(lines[range_info['start']:range_info['end']])
    f.writelines(footer)
