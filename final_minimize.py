import sys
import re
import os

with open('fun_ranges.txt', 'r') as f:
    funs = {}
    for line in f:
        name, start, end = line.split()
        funs[name] = {'start': int(start)-1, 'end': int(end)}

with open('lit-tests/scratch/minimize.ssa.bak', 'r') as f:
    lines = f.readlines()

fun_names = set(funs.keys())

def get_mentions(name):
    range_info = funs[name]
    body = "".join(lines[range_info['start']:range_info['end']])
    mentions = set()
    # Simple regex to find mentions
    found = re.findall(r'\b([a-zA-Z0-9_\']+)\b', body)
    for f in found:
        if f in fun_names and f != name:
            mentions.add(f)
    return mentions

necessary = {'main_4', 'f_1341'}
to_visit = ['main_4', 'f_1341']

while to_visit:
    curr = to_visit.pop()
    mentions = get_mentions(curr)
    for m in mentions:
        if m not in necessary:
            necessary.add(m)
            to_visit.append(m)

print(f"Necessary functions: {len(necessary)}")

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
    # Keep original order
    sorted_funs = sorted(funs.items(), key=lambda x: x[1]['start'])
    for name, range_info in sorted_funs:
        if name in necessary:
            f.writelines(lines[range_info['start']:range_info['end']])
    f.writelines(footer)
