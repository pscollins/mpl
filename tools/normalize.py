#!/usr/bin/env python3
import sys
import argparse

def remove_comments(text):
    """Removes nested SML-style comments (* ... *)."""
    result = []
    depth = 0
    i = 0
    n = len(text)
    
    while i < n:
        if i + 1 < n and text[i:i+2] == '(*':
            depth += 1
            i += 2
        elif i + 1 < n and text[i:i+2] == '*)':
            if depth > 0:
                depth -= 1
                i += 2
            else:
                # Unmatched closing comment - just treat it as text or ignore?
                # Usually in SML this is a syntax error, but we'll just keep it.
                result.append(text[i])
                i += 1
        elif depth == 0:
            result.append(text[i])
            i += 1
        else:
            i += 1
            
    return "".join(result)

def main():
    parser = argparse.ArgumentParser(description="Normalize SML-style source files.")
    parser.add_argument("--infile", required=True, help="Input file path")
    parser.add_argument("--outfile", required=True, help="Output file path")
    
    args = parser.parse_args()
    
    try:
        with open(args.infile, 'r') as f:
            content = f.read()
            
        # 1. Remove comments
        content_no_comments = remove_comments(content)
        
        # 2. Delete blank lines
        lines = content_no_comments.splitlines()
        normalized_lines = [line for line in lines if line.strip()]
        
        with open(args.outfile, 'w') as f:
            f.write("\n".join(normalized_lines) + "\n")
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
