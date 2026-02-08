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
OUTDIR=# TODO: SET IT TO THE LAST ARGUMENT
INFILE=# TODO: SET IT TO THE SECOND TO LAST ARGUMENT
COMPILE_ARGS=# TODO: SET IT TO ALL THE OTHER EARLIER ARGUMENTS

OUTFILE=${OUTDIR}/out.bin
# -keep-pass doesn't respect -output, so we need to run in ${OUTDIR}.
cd ${OUTDIR}
# Pass the earlier arguments as-is and use the absolute path for the last one
${MPL} -output ${OUTFILE} "${COMPILE_ARGS[@]}" "$INFILE"
