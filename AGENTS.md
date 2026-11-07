# Repository guide

Orb2DS is a native MATLAB library for transfers from periodic Earth-Moon orbits
through lunar encounters to prescribed outgoing Earth excess velocities.

## Layout and entry points

The repository root contains `+orb2ds`, `examples`, `tests`, `docs` and `data`.
Add only the root to MATLAB's path. Use `README.md` for setup,
`examples/config_database.m` and `examples/config_transfer.m` for the separate
generation and transfer configurations, `examples/workspace` for a copyable
user project, and
`docs/CONTRACTS.md` for input/output structures. Numerical defaults are in
`+orb2ds/+defaults/numerical_options.m`.

## Code and documentation

Keep scientific stages directly callable and share them with `find_transfer`.
Use explicit units, frames, timing definitions and compact data structures.
Results contain the data needed for reconstruction; sampled trajectories and
figures belong to separate transient objects.

Saving is explicit. Prepare and authorize destinations before numerical work,
then save completed data in the user's project. See `docs/OUTPUT.md`; scientific
solvers do not create result folders or request file-overwrite confirmation.

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
