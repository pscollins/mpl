# Pre-Flatten Unit Tests

This directory contains unit tests for the `PreFlatten` pass in the SSA IR. Due to the large number of test cases, they have been split into multiple files for better maintainability and faster compilation.

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
1. If a test group has fewer than 10 tests, add it to the latest `pre-flatten-test-N.sml`.
2. If all current groups are full, create a new `pre-flatten-test-(N+1).sml` and a corresponding `pre-flatten-test-(N+1).mlb`.
3. The `Makefile` uses wildcards, so it will automatically pick up new `pre-flatten-test-[0-9]*.mlb` files.
