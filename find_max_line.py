
import re

def main():
    with open('necessary_functions.txt', 'r') as f:
        necessary = set([line.strip() for line in f.readlines()])
    
    with open('lit-tests/scratch/original.ssa', 'r') as f:
        lines = f.readlines()
    
    max_line = 0
    for i, line in enumerate(lines):
        m = re.match(r'^fun (?:(?:__inline_never__|__inline_always__)\s+)?([a-zA-Z0-9_\']+) \(', line)
        if m:
            fun_name = m.group(1)
            if fun_name in necessary:
                max_line = i
    
    print(f"Max line needed: {max_line}")

if __name__ == '__main__':
    main()
