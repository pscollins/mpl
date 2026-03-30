
import re

def main():
    with open('lit-tests/scratch/original.ssa', 'r') as f:
        content = f.read()
    
    funs = list(re.finditer(r'^fun (?:(?:__inline_never__|__inline_always__)\s+)?([^ ]+) \(', content, re.MULTILINE))
    fun_map = {}
    for i in range(len(funs)):
        start = funs[i].start()
        next_fun = re.search(r'^fun ', content[funs[i].end():], re.MULTILINE)
        if next_fun:
            end = funs[i].end() + next_fun.start()
        else:
            end = content.find('\n main_4')
            if end == -1: end = len(content)
        
        fun_name = funs[i].group(1)
        fun_map[fun_name] = content[start:end]

    header = content[:funs[0].start()]
    
    target = 'f_1341'
    target_body = fun_map[target]
    
    symbols = set(re.findall(r'[^ \(\)\n,\[\]{}#:]+', target_body))
    dependencies = symbols.intersection(fun_map.keys())
    if target in dependencies: dependencies.remove(target)
    
    dummy_main = """
fun __inline_never__ main_4 (): {returns = Some (unit), raises = None} =
L_0 ()
  block L_0 ()
    val x_0: real64 = 0.0:r64
    val l31: lambdas_31 = con sched_packageEnv_0 (ref (con xEnv_119 ((0x0:w32, con classEnv_1 ((0x0:w32, 0x0:w32, 0x0:w32)), con classEnv_1 ((0x0:w32, 0x0:w32, 0x0:w32)), con <<Env_0 ((0x0:w32, 0x0:w64)), con >>Env_0 ((0x0:w32, 0x0:w64)))))))
    val x_1: lambdas_28 = con parEnv_0 ((l31, con xEnv_0 (()), con xEnv_0 (()), ref (())))
    val tuple_190: (real64, lambdas_28) tuple = (x_0, x_1)
    val x_2: word32 = 0x0:w32
    call L_1 (f_1341 (tuple_190, x_2)) handle _ => L_2
  block L_1 (x_3: unit)
    return (())
  block L_2 (x_4: exn)
    return (())

 main_4
"""

    with open('lit-tests/scratch/minimize.ssa', 'w') as f:
        f.write(header)
        f.write(target_body)
        for dep in sorted(list(dependencies)):
            orig_body = fun_map[dep]
            m = re.search(r'^(\s+L_[0-9]+|block L_[0-9]+)', orig_body, re.MULTILINE)
            if m:
                sig = orig_body[:m.start()]
                l_match = re.search(r'=\s+(L_[0-9]+)\s+\(\)', sig)
                if l_match:
                    l_entry = l_match.group(1)
                    f.write(f"{sig}{l_entry} ()\n  block {l_entry} ()\n    bug\n")
                else:
                    f.write(f"{sig}  block L_999999 ()\n    bug\n")
        f.write(dummy_main)

if __name__ == '__main__':
    main()
