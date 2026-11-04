# Repository guide

Orb2DS is a native MATLAB library for transfers from periodic Earth-Moon orbits
through lunar encounters to prescribed outgoing Earth excess velocities.

## Layout and entry points

The repository root contains `+orb2ds`, `examples`, `tests`, `docs` and `data`.
Add only the root to MATLAB's path. Use `README.md` for setup,
`examples/config_example.m` for the complete configuration, and
`docs/CONTRACTS.md` for input/output structures. Numerical defaults are in
`+orb2ds/+defaults/numerical_options.m`.

## Code and documentation

Keep scientific stages directly callable and share them with `find_transfer`.
Use explicit units, frames, timing definitions and compact data structures.
Results contain the data needed for reconstruction; sampled trajectories and
figures belong to separate transient objects.

Keep code short, readable and well formatted, with informative function headers
and brief comments between meaningful stages. MATLAB example scripts begin
with `clc; close all; clear;`, then add the library root to the path.

Write comments and documentation for users of the current repository. Explain
supported settings, defaults, units, alternatives and errors at their point of
use. Describe algorithms directly. Keep development logs and source-comparison
reports under the Git-ignored `.dev` directory. Preserve third-party attribution
and license notices.

## Verification

Run the tests relevant to a behavior change. For a documentation-only change,
verify that executable statements and configuration values remain unchanged.
Report solver stopping status, local physical checks and chained propagation
separately; optimizer convergence alone does not establish transfer acceptance.
