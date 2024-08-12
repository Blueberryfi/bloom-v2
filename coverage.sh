#!/bin/bash
forge clean
forge coverage --ir-minimum --report lcov
genhtml -o coverage lcov.info --ignore-errors inconsistent
cd coverage
open index.html