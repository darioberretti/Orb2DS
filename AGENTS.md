# Project handoff

This repository is the baseline for a public, expandable RPO-to-deep-space trajectory-generation method. It was extracted on 2026-08-08 from the private thesis workspace at `C:\Users\dario\Desktop\TESI\Code`.

The method is intentionally modular. It must support progressively constrained problems: relatively free benchmark formulations, fixed phase or timing variants, operational epochs, realistic mission constraints, reachability studies, and interchangeable solver adapters. Minimal means canonical representations and little duplicated logic, not a single supported path.

Current state (2026-10-26): Orb2DS is both the repository and library root. Its native MATLAB implementation is in `+orb2ds`, beside `examples`, `tests`, `docs` and `data`. Start with `README.md`, `examples/config_example.m` and the contracts, validation and provenance documents in `docs`. The historical baseline and development outputs have a complete verified local snapshot in `.dev/archive/2026-10-26`, excluded from Git. Archived files are not runtime dependencies; do not add the archive to the MATLAB path or overwrite it during new work.

Original migration roadmap (measured completion status is in `docs/IMPLEMENTATION_STATUS.md`; the historical design and selection notes are archived locally):

1. Define exact versioned contracts for both input databases and the patched-seed output.
2. Trace one end-to-end case and remove any dependency on the original `Code` repository.
3. Reconstruct database generation, matching, seed assembly, constraints, objectives, profiles, and solver adapters one module at a time.
4. Simplify line by line while preserving scientific modes and numerical behavior.
5. Replace or license external OM/Lambert/ephemeris dependencies before publication.

MATLAB example scripts must begin with `clc; close all; clear;`, then add the library root containing `+orb2ds` to the search path. The agreed layout places `+orb2ds` beside `examples`, `tests` and `docs`; do not introduce a `Functions` layer or require recursive path setup. Do not add `+orb2ds` itself to the path. Historical scripts remain archived with their original paths. Put documented user settings first, keep code simple, add short one-line comments, and do not add fallbacks or error-message branches.

Large datasets remain in the private thesis workspace for now. Do not add that workspace to the MATLAB path as a permanent solution; missing public data should later be packaged as a release asset or DOI-backed archive.
