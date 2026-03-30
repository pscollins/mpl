
import subprocess
import os

def run_test():
    result = subprocess.run(['bash', 'lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return "Found forbidden tuple operations" in result.stdout

def main():
    with open('lit-tests/scratch/original.ssa', 'r') as f:
        lines = f.readlines()
    
    # Keep lines 1 to 6057 (preamble)
    preamble = lines[:6057]
    # Keep lines 48280 to end (footer)
    footer = lines[48280:]
    # Middle part (functions)
    middle = lines[6057:48280]
    
    print(f"Total middle lines: {len(middle)}")
    
    # Bisection on middle lines
    current_middle = middle
    chunk_size = len(current_middle) // 4
    
    while chunk_size > 0:
        print(f"Trying chunk size: {chunk_size}")
        i = 0
        while i < len(current_middle):
            test_middle = current_middle[:i] + current_middle[i+chunk_size:]
            with open('lit-tests/scratch/minimize.ssa', 'w') as f:
                f.writelines(preamble + test_middle + footer)
            
            if run_test():
                print(f"Removed {chunk_size} lines at index {i}")
                current_middle = test_middle
            else:
                i += chunk_size
        chunk_size //= 2
    
    print(f"Final size: {len(current_middle)}")

if __name__ == '__main__':
    main()
