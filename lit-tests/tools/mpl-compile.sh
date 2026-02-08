#!/bin/bash
#
# Wrapper script to compile a binary under `mpl` and keep any output files in
# the LIT test-supplied %t.
#
# Requires that it is called in the LIT test as
#
#   mpl-compile.sh [OPTIONAL FLAGS] source_file.sml %t
set -e
set -x
SCRIPT_DIR=$(dirname $(realpath $0))
MPL=${SCRIPT_DIR}/../../build/bin/mpl
# Out directory must be the last argument
OUTDIR="${@: -1}"
# Input file must be the second to last argument, and we make it absolute here
INFILE=$(realpath "${@: -2: 1}")
# Everything beforehand gets passed to the compiler
COMPILE_ARGS=("${@: 1: $# - 2}")

OUTFILE=${OUTDIR}/out.bin
# -keep-pass doesn't respect -output, so we need to run in ${OUTDIR}.
mkdir -p ${OUTDIR}
cd ${OUTDIR}
# Pass the earlier arguments as-is and use the absolute path for the input file
${MPL} -output ${OUTFILE} "${COMPILE_ARGS[@]}" "$INFILE"
