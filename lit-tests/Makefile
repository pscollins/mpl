# Paths
DEPS_FILE := requirements.txt
VENV_DIR  := tests/.venv
VENV_BIN  := $(VENV_DIR)/bin
# TEMPORARY HACK: limit cores
LIT       := $(VENV_BIN)/lit -j1
PIP       := $(VENV_BIN)/pip

# Phony targets (targets that are not actual files)
.PHONY: test clean

# Main test target
# "test" depends on $(LIT) existing. If it doesn't, Make runs the install step first.
test: $(LIT)
	$(LIT) -v tests/

# Rule to create the virtual environment and install lit
# This only runs if $(LIT) is missing or if the Makefile changes
$(LIT):
	@echo "Setting up virtual environment..."
	python3 -m venv $(VENV_DIR)
	$(PIP) install --upgrade pip
	$(PIP) install lit
	@echo "Setup complete."

# Utility to remove the venv
clean:
	rm -rf $(VENV_DIR)
