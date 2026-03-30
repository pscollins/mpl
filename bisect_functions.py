
import re
import subprocess
import os

def run_test():
    try:
        # We need to make sure minimize.ssa exists before calling test.sh
        if not os.path.exists('lit-tests/scratch/minimize.ssa'):
            return False
        result = subprocess.run(['bash', 'lit-tests/scratch/test.sh'], 
                                capture_output=True, text=True, timeout=60)
        return "Found forbidden tuple operations" in result.stdout
    except:
        return False

def save_ssa(header, fun_map, footer, fun_names):
    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.write(header)
        for name in fun_names:
            f.write(fun_map[name])
        f.write(footer)

def main():
    with open('lit-tests/scratch/original.ssa', 'r') as f:
        content = f.read()
    
    funs = list(re.finditer(r'^fun (?:(?:__inline_never__|__inline_always__)\s+)?([^ ]+) \(', content, re.MULTILINE))
    fun_map = {}
    for i in range(len(funs)):
        start = funs[i].start()
        if i + 1 < len(funs): end = funs[i+1].start()
        else: end = content.find('\n main_4')
        fun_map[funs[i].group(1)] = content[start:end]

    header = content[:funs[0].start()]
    footer = content[content.find('\n main_4'):]
    
    current_funs = [m.group(1) for m in funs]
    
    chunk_size = len(current_funs) // 2
    while chunk_size > 0:
        print(f"Trying chunk size: {chunk_size}")
        i = 0
        while i < len(current_funs):
            # Try removing current_funs[i : i+chunk_size]
            chunk = current_funs[i : i+chunk_size]
            
            # NEVER remove main_4 or f_1341
            if 'main_4' in chunk or 'f_1341' in chunk:
                i += chunk_size
                continue
                
            test_funs = current_funs[:i] + current_funs[i+chunk_size:]
            save_ssa(header, fun_map, footer, test_funs)
            
            if run_test():
                print(f"Removed {len(chunk)} functions at index {i}")
                current_funs = test_funs
            else:
                i += chunk_size
        chunk_size //= 2
    
    save_ssa(header, fun_map, footer, current_funs)
    print(f"Final functions count: {len(current_funs)}")

if __name__ == '__main__':
    main()
