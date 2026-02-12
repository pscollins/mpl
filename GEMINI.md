# Project Background

This project is the `mpl` compiler, a parallel dialect of Standard ML. The
codebase is a fork of MLton.

## Workflows

* To rebuild the entire project (both the basis and the compiler), run `make` in
  the project root

* To rebuild the compiler alone, run `make compiler`, and to rebuild the basis
  alone, run `make basis`.

* To test that a particular file compiles under the `mpl` compiler (i.e. a
  source file input to `mpl`, rather than a part of `mpl` itself), prefer a
  command like the following:
```
build/bin/mpl -output build/tmp_out.bin $INFILE
```


## Tools
Version control in this project is managed via `jj` wrapped around `git`.
