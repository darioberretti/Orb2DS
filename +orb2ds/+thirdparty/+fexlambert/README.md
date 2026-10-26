# FEX-Lambert v1.4

This directory vendors the two files required from Rody Oldenhuis's
[FEX-Lambert v1.4](https://github.com/rodyo/FEX-Lambert/releases/tag/v1.4).

- Upstream commit: `f220826e6ac688ae8dfd2e8c9374872e43ea9fb4`
- Upstream `lambert.m` SHA-256:
  `9ECF58DC1CD1F5C9B8F3BAB904B9A496165D23FD8217055810D926EC1F2551F7`
- License: 2-clause BSD; see `License.txt`

The source file is kept under its upstream name. Repository code calls it
through `rpo2ds.solve_lambert`, which fixes the units, array shapes, and
zero-revolution short-way branch used by this reproduction.
