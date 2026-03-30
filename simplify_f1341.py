import sys
import subprocess
import os

with open('lit-tests/scratch/minimize.ssa.bak', 'r') as f:
    lines = f.readlines()

f_1341_start = 13005 - 1
f_1341_end = 13036

def test_new_f1341(new_body):
    new_lines = lines[:f_1341_start+1] + new_body + lines[f_1341_end:]
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.writelines(new_lines)
    res = subprocess.run(['./lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return res.returncode == 0

# Original body simplified
new_body = [
    "  block L_1867 ()\n",
    "    val x_78256: real64 = #0 (env_715)\n",
    "    val _: real64 = prim Trace_noTuple[real64] (x_78256)\n",
    "    return (x_76660 )\n"
]

if test_new_f1341(new_body):
    print("Simplified f_1341 SUCCEEDED")
else:
    print("Simplified f_1341 FAILED")
