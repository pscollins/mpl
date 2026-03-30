import sys
import subprocess
import os

with open('lit-tests/scratch/minimize.ssa.bak', 'r') as f:
    lines = f.readlines()

header_end = 6058 - 1
header = lines[:header_end]
rest = lines[header_end:]

def test_header(new_header):
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.writelines(new_header)
        f.writelines(rest)
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

current_header = header
print(f"Starting with {len(current_header)} lines in header")

chunk_size = 100
i = 0
while i < len(current_header):
    # Try to remove chunk
    test_h = current_header[:i] + current_header[i+chunk_size:]
    print(f"Testing removal of header lines {i} to {i+chunk_size}")
    if test_header(test_h):
        print(f"Removed lines {i} to {i+chunk_size}")
        current_header = test_h
        # Don't increment i
    else:
        if chunk_size > 1:
            chunk_size //= 2
        else:
            i += 1
            chunk_size = 100

print(f"Final header lines: {len(current_header)}")
test_header(current_header)
