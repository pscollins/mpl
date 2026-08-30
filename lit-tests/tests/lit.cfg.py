import lit.formats
import pathlib
import os

# Name of the test suite
config.name = 'MPL LIT Tests'

# File extensions to treat as test files
config.suffixes = ['.sml']

config.test_format = lit.formats.ShTest()

# The root path where tests are located
config.test_source_root = os.path.dirname(__file__)

# Base paths to tools
SOURCE_ROOT = pathlib.Path(config.test_source_root)
TOOLS_ROOT = SOURCE_ROOT.parent / 'tools'
OUTPUT_ROOT = SOURCE_ROOT.parent / 'output'

# Add a wrapper to run programs under MPL

# Tool to compile+run under mpl
MPL_RUN_TOOL = str(TOOLS_ROOT / 'mpl-run.sh')
config.substitutions.append(('mpl-run', MPL_RUN_TOOL))
# Tool to print the generated C
MPL_PRINT_C_TOOL = str(TOOLS_ROOT / 'mpl-print-c.sh')
config.substitutions.append(('mpl-print-c', MPL_PRINT_C_TOOL))
# Tool to compile under mpl and keep outputs in %t
MPL_COMPILE_TOOL = str(TOOLS_ROOT / 'mpl-compile.sh')
config.substitutions.append(('mpl-compile', MPL_COMPILE_TOOL))

# Check if the user provided a custom build directory via --param
user_build_dir = lit_config.params.get('build_dir', None)
if user_build_dir:
    # Override the execution root to the user-specified directory
    config.test_exec_root = os.path.abspath(user_build_dir)
else:
    # Default behavior (usually set to the current build directory)
    config.test_exec_root = OUTPUT_ROOT
