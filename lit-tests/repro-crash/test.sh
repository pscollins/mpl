# This script attempts to compile the bug-reproducer contained in this directory
# and prints `PASS` if the reproducer still exercises the case that we are
# trying to debug (good!) and prints `FAIL` otherwise (bad!)

cd $(dirname $0)
TEMPFILE=$(mktemp)
make clean
make test 2>&1 | tee $TEMPFILE
if grep -q "Found forbidden tuple operations" $TEMPFILE; then
    echo "Test PASS -- bug still present!"
    exit 0
else
    echo "Test FAIL! BUG NO LONGER REPRODUCES!"
    exit 1
fi
