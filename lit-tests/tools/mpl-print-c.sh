#!/bin/bash
#
# Wrapper script to compile a binary under `mpl` and print the generated C
#
# Requires that it is called as:
#   mpl-print-c.sh [OPTIONAL FLAGS] source_file.sml
set -e
set -x
SCRIPT_DIR=$(dirname $(realpath $0))
# MPL=${SCRIPT_DIR}/../../build/bin/mlton-mpl.debug
MPL=${SCRIPT_DIR}/../../build/bin/mpl
OUTDIR=$(mktemp -d)

# Check if OVERRIDE_OUTDIR is provided and non-empty
if [ -n "$OVERRIDE_OUTDIR" ]; then
    OUTDIR="$OVERRIDE_OUTDIR"
    # Create the directory if it doesn't exist
    mkdir -p "$OUTDIR"
    echo "Running in ${OUTDIR} (Persisting output)"
else
    # Otherwise, generate a temporary directory + cleanup
    OUTDIR=$(mktemp -d)
    echo "Running in ${OUTDIR}"

    cleanup() {
        rm -rf "$OUTDIR"
    }
    # Only set the trap if we created the temp directory
    trap cleanup EXIT
fi

OUTFILE=${OUTDIR}/out.bin
# -keep-pass doesn't respect -output, so we need to run in ${OUTDIR}.
#
# Extract the last argument and make it absolute
# ${@: -1} grabs the last arg, ${@:1:$#-1} grabs everything else
LAST_ARG=$(realpath "${@: -1}")
OTHER_ARGS=("${@:1:$#-1}")
cd ${OUTDIR}
# Pass the earlier arguments as-is and use the absolute path for the last one
${MPL} -output ${OUTFILE} -keep g "${OTHER_ARGS[@]}" "$LAST_ARG"
cat ${OUTFILE}.*.c
