import argparse
import os
import sys

def split_file(infile, chunks, out_base):
    if not os.path.exists(infile):
        print(f"Error: Input file '{infile}' not found.")
        sys.exit(1)

    with open(infile, 'r') as f:
        lines = f.readlines()

    total_lines = len(lines)
    if total_lines == 0:
        print("Error: Input file is empty.")
        sys.exit(1)

    if chunks <= 0:
        print("Error: Number of chunks must be greater than 0.")
        sys.exit(1)

    if chunks == 1:
        with open(f"{out_base}.1", 'w') as f:
            f.writelines(lines)
        return

    # Find all possible split points (indices of lines starting with non-whitespace)
    # We exclude index 0 because it's always the start of the first chunk.
    valid_starts = [i for i, line in enumerate(lines) if i > 0 and line and not line[0].isspace()]

    if len(valid_starts) < chunks - 1:
        print(f"Warning: Only found {len(valid_starts)} valid split points, but requested {chunks} chunks.")

    # Pick N-1 split points from valid_starts
    split_indices = []
    if valid_starts:
        target_step = total_lines / chunks
        current_target = target_step
        
        for _ in range(chunks - 1):
            # Find the valid start closest to current_target that is after the last split index
            best_idx = -1
            min_diff = float('inf')
            
            last_split = split_indices[-1] if split_indices else 0
            
            for v_idx in valid_starts:
                if v_idx <= last_split:
                    continue
                diff = abs(v_idx - current_target)
                if diff < min_diff:
                    min_diff = diff
                    best_idx = v_idx
                elif v_idx > current_target:
                    # Since valid_starts is sorted, we can break early if we're moving away from target
                    break
            
            if best_idx != -1:
                split_indices.append(best_idx)
                current_target += target_step
            else:
                # No more valid starts available
                break

    # Perform the split
    all_splits = [0] + split_indices + [total_lines]
    for i in range(len(all_splits) - 1):
        start = all_splits[i]
        end = all_splits[i+1]
        chunk_lines = lines[start:end]
        output_file = f"{out_base}.{i+1}"
        with open(output_file, 'w') as f:
            f.writelines(chunk_lines)
        print(f"Wrote {len(chunk_lines)} lines to {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split a file into N chunks starting on non-whitespace characters.")
    parser.add_argument("--infile", required=True, help="Input file path")
    parser.add_argument("--chunks", type=int, required=True, help="Number of chunks")
    parser.add_argument("--out_base", required=True, help="Base name for output files")

    args = parser.parse_args()
    split_file(args.infile, args.chunks, args.out_base)
