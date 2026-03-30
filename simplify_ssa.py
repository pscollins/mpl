
import re
import subprocess

def run_test():
    result = subprocess.run(['bash', 'lit-tests/scratch/test.sh'], capture_output=True, text=True)
    return "Found forbidden tuple operations" in result.stdout

def main():
    with open('lit-tests/scratch/original.ssa', 'r') as f:
        content = f.read()
    
    # 1. Split into preamble, functions, and footer
    funs = list(re.finditer(r'^fun (?:(?:__inline_never__|__inline_always__)\s+)?([a-zA-Z0-9_\']+) \(', content, re.MULTILINE))
    fun_map = {}
    fun_sig = {}
    for i in range(len(funs)):
        start = funs[i].start()
        # Find signature end (usually where the block starts)
        # Search for first 'L_[0-9]+ ()' or 'bug' after 'fun ... ='
        sig_end_match = re.search(r'=(?:\s+L_[0-9]+\s+\(\))?\n(\s+L_[0-9]+\s+\(\)|\s+block\s+L_[0-9]+)', content[funs[i].end():], re.MULTILINE)
        
        # Actually, simpler: Signature is everything up to the first newline after '='
        # But some sigs have newlines.
        # Let's just find the next function start.
        if i + 1 < len(funs):
            end = funs[i+1].start()
        else:
            end = content.find('\n main_4')
            if end == -1: end = len(content)
            
        fun_name = funs[i].group(1)
        body = content[start:end]
        fun_map[fun_name] = body
        
        # Extract signature
        # Signature ends at the first block definition or L_ entry point
        m = re.search(r'^(\s+L_[0-9]+|block L_[0-9]+)', body, re.MULTILINE)
        if m:
            sig = body[:m.start()]
            fun_sig[fun_name] = sig
        else:
            fun_sig[fun_name] = body

    header = content[:funs[0].start()]
    footer = content[content.find('\n main_4'):]
    
    # 2. Try simplifying bodies
    to_simplify = list(fun_map.keys())
    # Keep main_4 and f_1341 intact
    if 'main_4' in to_simplify: to_simplify.remove('main_4')
    if 'f_1341' in to_simplify: to_simplify.remove('f_1341')
    
    print(f"Total functions to simplify: {len(to_simplify)}")
    
    current_simplified = set()
    
    chunk_size = len(to_simplify) // 2
    while chunk_size > 0:
        print(f"Trying chunk size: {chunk_size}")
        i = 0
        while i < len(to_simplify):
            chunk = to_simplify[i : i+chunk_size]
            new_simplified = current_simplified.union(set(chunk))
            
            # Save SSA
            with open('lit-tests/scratch/minimize.ssa', 'w') as f:
                f.write(header)
                for name in fun_map.keys():
                    if name in new_simplified:
                        # Simplified body
                        # We need an entry point label
                        m = re.search(r'=\s+(L_[0-9]+)\s+\(\)', fun_sig[name])
                        if m:
                            l_entry = m.group(1)
                            f.write(f"{fun_sig[name]}{l_entry} ()\n  block {l_entry} ()\n    bug\n")
                        else:
                            # Fallback
                            f.write(f"{fun_sig[name]}  block L_999999 ()\n    bug\n")
                    else:
                        f.write(fun_map[name])
                f.write(footer)
            
            if run_test():
                print(f"Simplified {len(chunk)} functions")
                current_simplified = new_simplified
                i += chunk_size
            else:
                i += chunk_size
        chunk_size //= 2
    
    print(f"Final simplified functions: {len(current_simplified)}")

if __name__ == '__main__':
    main()
