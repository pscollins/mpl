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
print(f"Reachable from main_4: {len(reachable)}")

# If everything is reachable, let's see which functions are NOT called by anyone except one function
# (the caller chain)
reverse_calls = {}
for name in fun_names:
    reverse_calls[name] = set()

for name, callers in calls.items():
    for c in callers:
        reverse_calls[c].add(name)

with open('reachable_from_main_4.txt', 'w') as f:
    for r in sorted(list(reachable)):
        f.write(r + '\n')

with open('all_calls_with_lines.txt', 'w') as f:
    for name, called_set in calls.items():
        f.write(f"{name} calls: {', '.join(sorted(list(called_set)))}\n")
