
import re
import subprocess

def run_test():
    try:
        result = subprocess.run(['bash', 'lit-tests/scratch/test.sh'], 
                                capture_output=True, text=True, timeout=60)
        return "Found forbidden tuple operations" in result.stdout
    except:
        return False

def get_dummy(body):
    m = re.search(r'^(\s+L_[0-9]+|block L_[0-9]+)', body, re.MULTILINE)
    if not m: return None
    sig = body[:m.start()]
    l_match = re.search(r'=\s+([^ ]+)\s+\(\)', sig)
    if not l_match:
        l_match = re.search(r'^\s+([^ ]+)\s+\(\)', body, re.MULTILINE)
    if not l_match: return None
    l_entry = l_match.group(1)
    return f"{sig}{l_entry} ()\n  block {l_entry} ()\n    bug\n"

def main():
    with open('lit-tests/scratch/minimize.ssa', 'r') as f:
        content = f.read()
    
    funs = list(re.finditer(r'^fun (?:(?:__inline_never__|__inline_always__)\s+)?([^ ]+) \(', content, re.MULTILINE))
    fun_names = [m.group(1) for m in funs]
    
    header = content[:funs[0].start()]
    footer = content[content.find('\n main_4'):]

    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.write(header)
        for i in range(len(funs)):
            name = fun_names[i]
            start = funs[i].start()
            if i + 1 < len(funs): end = funs[i+1].start()
            else: end = content.find('\n main_4')
            body = content[start:end]
            
            if name in ['main_4', 'f_1341']:
                f.write(body)
            else:
                dummy = get_dummy(body)
                if dummy: f.write(dummy)
                else: f.write(body)
        f.write(footer)
    
    if run_test():
        print("Success! Simplified everything in minimize.ssa.")
    else:
        print("Failed to simplify. Reverting.")

if __name__ == '__main__':
    main()
