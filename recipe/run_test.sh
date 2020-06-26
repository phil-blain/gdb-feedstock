#!/usr/bin/env bash
set -ex

echo "CONDA_PY:$CONDA_PY"
export CONDA_PY=`python -c "import sys;print('%s%s'%sys.version_info[:2])"`
echo "CONDA_PY:$CONDA_PY"

if [[ $(uname) == "Darwin" ]]; then
  sudo /usr/sbin/DevToolsSecurity -enable
  sudo security authorizationdb write system.privilege.taskport allow
fi

# Run hello world test
$CC -o hello -g "$RECIPE_DIR/testing/hello.c"
gdb -batch -ex "run" --args hello

# Run python test
if [[ $(uname) == "Darwin" ]]; then
  # Skip python test on macOS, since the Python executable is missing debug symbols.
  # see https://github.com/conda-forge/gdb-feedstock/pull/23/#issuecomment-643008755
  # and https://github.com/conda-forge/python-feedstock/issues/354
  exit 0
fi
gdb -batch -ex "run" -ex "py-bt" --args python "$RECIPE_DIR/testing/process_to_debug.py" | tee gdb_output

if [[ "$CONDA_PY" != "27" ]]; then
    grep "built-in method kill" gdb_output
fi
# Unfortunately some python packages do not have enough debug info for py-bt
if [[ "$CONDA_PY" != "36" ]]; then
    grep "line 3" gdb_output
    grep "process_to_debug.py" gdb_output
    grep 'os.kill(os.getpid(), signal.SIGSEGV)' gdb_output
else
    if grep "line 3" gdb_output; then
        echo "This test was expected to fail due to missing debug info in python"
        echo "As it passed the test should be re-enabled"
        exit 1
    fi
fi

grep "Program received signal SIGSEGV" gdb_output
