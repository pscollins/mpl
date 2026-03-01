# Special notes

This directory contains unit tests (defined in the `Makefile`). Unlike much of
the project, these unit tests do not depend on the main `mpl` compiler binary --
they use the host SML instead.

To run these tests, examine the contents of the `Makefile` and choose the
appropriate commands for the task -- do not rebuild the entire `mpl` compiler
first.
