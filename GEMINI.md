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

* For unit tests of a single library or pass within the compiler, there is no
  need to rebuild the compiler or the basis as a whole (which is quite slow) --
  just build and run the particular unit test target that you're working on.


## Tools
Version control in this project is managed via `jj` wrapped around `git`. Never
interact with `git` directly -- always use `jj` instead.

## Formatting
While existing files may have a copyright comment at the top, new files that are
created in this repositiory should not have a copyright comment added.
