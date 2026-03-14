import argparse
from rssa import parse_rssa, Function, Block, Statement, Transfer
import sys

def main():
    parser = argparse.ArgumentParser(description="Extract use-def subgraph from RSSA IR")
    parser.add_argument("--trace_value", required=True, help="The value to trace")
    parser.add_argument("--infile", required=True, help="The RSSA IR file")
    args = parser.parse_args()

    with open(args.infile, 'r') as f:
        content = f.read()

    program = parse_rssa(content)
    subgraph_elements = program.get_use_def_subgraph(args.trace_value)

    if not subgraph_elements:
        print(f"Value {args.trace_value} not found or has no relations.")
        return

    # Sort elements for deterministic output
    # Group by function and then by block
    grouped = {}
    for f, b, e in subgraph_elements:
        f_name = f.name.name
        if f_name not in grouped:
            grouped[f_name] = {"func": f, "blocks": {}}
        
        b_label = b.label.name if b else "Header"
        if b_label not in grouped[f_name]["blocks"]:
            grouped[f_name]["blocks"][b_label] = {"block": b, "elements": []}
        
        grouped[f_name]["blocks"][b_label]["elements"].append(e)

    for f_name in sorted(grouped.keys()):
        f_info = grouped[f_name]
        f_obj = f_info["func"]
        print(f"fun {f_obj.name} (...):")
        
        for b_label in sorted(f_info["blocks"].keys()):
            b_info = f_info["blocks"][b_label]
            if b_label == "Header":
                print("  Header:")
                for e in b_info["elements"]:
                    if isinstance(e, Function):
                        print(f"    Args: {', '.join([str(a[0]) for a in e.args])}")
            else:
                b_obj = b_info["block"]
                print(f"  {b_label} ({', '.join([str(a[0]) for a in b_obj.args])}) =")
                # We should try to keep the order of statements as in the original block
                # but subgraph might only have some of them.
                all_b_elements = b_info["elements"]
                
                # Sort elements based on their appearance in the original block
                def get_order(e):
                    if e == b_obj: return -1 # Header
                    try:
                        return b_obj.statements.index(e)
                    except ValueError:
                        if e == b_obj.transfer: return len(b_obj.statements)
                        return 999
                
                for e in sorted(all_b_elements, key=get_order):
                    if e == b_obj: continue # Already printed label
                    print(f"    {e}")

if __name__ == "__main__":
    main()
