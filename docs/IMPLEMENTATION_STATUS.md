# MATLAB implementation status

The first native MATLAB implementation is complete, with the namespace
`orb2ds` directly in the repository root. The repository folder is now `Orb2DS`;
the temporary `LibraryName` and nested library directory have been removed.
The old baseline and development outputs have a complete verified local
snapshot in `.dev/archive/2026-10-26`, excluded from version control. The distinct historical
source and audit records are retained there too. The sibling source tree and
Git history were not modified by that cleanup. The project code and documentation
are now MIT-licensed, with separately licensed Lambert source preserved. The
native Python port remains planned.

Implemented:

- Separate case preparation and execution with copyable configuration functions.
- Atomic leg matching, physical flyby assembly, meshing and standalone optimization.
- Coherent spatial Earth-Moon CR3BP, explicit units, normalized orbit phase,
  ECI/RTH targets and optional initial phase/epoch.
- Versioned orbit-Moon database generation, loading and compatible caching.
- Native two-stage fmincon SQP with Oshima impulses, analytic shooting STMs,
  timing/clearance/impulse constraints and deterministic multistart.
- Independent physical validation, including chained propagation through all burns.
- Compact self-contained results, explicit reconstruction and plotting.
- Runnable examples, a small canonical catalogue, regression tests and source hashes.

The complete annotated configuration is `examples/config_example.m`; there is
no required `cases` directory. It includes every supported numerical field and
loads unchanged after copying outside the library. All 35 tests pass after
the 2026-10-25 configuration/plotting/display updates. The fresh
2026-10-24 public-API example converges at 272.6383526 m/s and
24.99911669 days; local validation and chained closure both pass. See
[VALIDATION.md](VALIDATION.md) and [validation.json](validation.json) for measured
results, historical control scope and verification limits.

The implementation preserves the thesis method's stages while explicitly
resolving historical scale/frame/data ambiguities. It does not promise the
same local optimum as the historical IPOPT calculation. See
[PROVENANCE.md](PROVENANCE.md) for source adaptations and
[CONTRACTS.md](CONTRACTS.md) for the implemented schema and settings.

Deferred scientific work: exact/windowed final epochs, MJD2000 and ephemeris
geometry, alternative objectives/backends, database-free initialization and
the native equivalent Python implementation. Wider orbit-family coverage
requires further benchmarks. Raster export was not verified; plot-object
construction and closure were checked independently.
