# Pre-Flatten Unit Tests

This directory contains unit tests for the `PreFlatten` pass in the SSA IR. Due to the large number of test cases, they have been split into multiple files for better maintainability and faster compilation.

## General guidance

When testing changes in this directory, *never* do a full `make compiler` -- you
should *always* rely on the corresponding unit tests instead, unless explicitly
instructed otherwise by the user.

## Test Structure

- `pre-flatten-test-common.sml`: Common boilerplate, helper functions, and shared test utilities.
- `pre-flatten-test-N.sml`: Individual test files, each containing approximately 10 test cases.
- `pre-flatten-test-N.mlb`: ML Basis files for each test group.

## How to Run Tests

### Run All Pre-Flatten Tests

To run the entire suite of pre-flatten tests:

```bash
make pre-flatten-tests
```

This will compile and execute all `pre-flatten-test-N.sml` files.

### Run a Specific Test Group

To run only a specific group of tests (e.g., group 1):

```bash
make pre-flatten-test-1.bin
```

### Run All SSA Unit Tests

To run all unit tests in this directory (including pre-flatten and others):

```bash
make unittest
```

## Adding New Tests

When adding new tests:
1. If the latest test file (e.g., `pre-flatten-test-N.sml`) is less than approximately 500 lines, add new tests to it.
2. Only create a new test file (e.g., `pre-flatten-test-(N+1).sml`) and its corresponding `.mlb` when the previous one has reached the 500-line threshold.
3. The `Makefile` uses wildcards, so it will automatically pick up new `pre-flatten-test-[0-9]*.mlb` files.
