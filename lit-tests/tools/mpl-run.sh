#!/bin/bash
set -e
SCRIPT_DIR=$(dirname $(realpath $0))
MPL=${SCRIPT_DIR}/../../build/bin/mpl
OUTDIR=$(mktemp -d)

cleanup() {
    rm -rf "$OUTDIR"
}
trap cleanup EXIT

OUTFILE=${OUTDIR}/out.bin
${MPL} -output ${OUTFILE} $@
./${OUTFILE}
