# Validation evidence

Verified locally on 2026-10-24 with MATLAB R2025b Update 5 and Optimization
Toolbox. [validation.json](validation.json) contains the measured report.
Only `LibraryName` was added to the path for the new implementation; the
historical source control ran in a separate process with its own source path.

## Fresh public-API transfer

The complete `load_case -> find_transfer` call used
the then-current `examples/cases/venus_case.m`, the packaged reduced catalogue and the default
two-stage fmincon implementation. It used no previous optimized initialization.
Initial departure epoch and phase were both free. The case limits flight to
50 days, Earth altitude to at least 1,000 km and Moon altitude to at least
100 km, with a declared three-dimensional ECI target.

The same example inputs are now in `examples/config_example.m`, the complete
copyable configuration template that replaced the former `cases` folder.

| Measured quantity | Result |
|---|---:|
| Status | `feasible_converged` |
| Total impulse | 272.6383526 m/s |
| Flight duration | 24.99911669 days |
| Shooting nodes | 48 |
| Optimization exit flag / iterations | 2 / 1,442 |
| Achieved outgoing excess-velocity error | below 3e-14 km/s |
| Chained endpoint position error | below 2e-5 km (2 cm) |
| Chained endpoint velocity error | below 1e-8 km/s |
| Chained excess-velocity error | below 3e-10 km/s |
| Minimum Earth / Moon altitude | approximately 1,000 / 154.1296 km |

The report independently repropagates the saved compact record. Small
floating-point differences between runs are expected; these bounds cover
both the original solve and the subsequent report. Both per-segment
`validation.is_feasible` and the separate `validation.chained.is_feasible`
passed. The latter chains every impulse from the first state without resetting
to stored nodes. This is one validated local solution, not evidence of a global
optimum or a complete search over orbit families.

## Regression coverage

All 29 tests passed, with zero failed or incomplete tests:

| Test file | Tests | Checks |
|---|---:|---|
| `test_numerical_core` | 7 | Coherent scales, reversal/period closure, independent STM finite differences, frame inverses and lunar velocity, Lambert endpoint, RTH epoch derivative, unknown options. |
| `test_database_and_io` | 3 | Actual catalogue generation/cache reuse and mismatch rejection, case-relative paths and restored working directory, reconstructed jumps. |
| `test_nlp_contract` | 6 | Oshima charts/cost, full constraint Jacobian finite differences, free/tied phase/epoch, waiting derivatives, impulse masks, intersecting caps and positive durations. |
| `test_pipeline_stages` | 4 | Fresh matching/assembly/mesh, encounter chronology and independent escape direction, empty search, unsupported final epoch and orbit mismatch. |
| `test_solution_contract` | 6 | Local/chained propagation, all initial phase/epoch combinations, waiting/total-time limits, moving RTH target, changed-target reuse, compact save/reconstruct. |
| `test_flyby_geometry` | 2 | Three-dimensional outgoing perigee sampler and independent local lunar SOI velocity versus incoming asymptote. |
| `test_multistart` | 1 | Two real feasibility solves, lowest validated cost selection and compact attempt records. |

Run from the library root with that root on the path:

```matlab
results = runtests(fullfile(pwd, 'tests'));
assertSuccess(results);
```

The optimized fixture tests validation/reconstruction/reinitialization. It does
not initialize the fresh transfer or fresh leg search. Tests recursively reject
sampled trajectories and function handles inside results. A compact solution
reconstructs after saving and reloading alone.

Additional real controls changed the ECI target's first component by 0.02 km/s
and obtained a validated converged transfer around 268.8178 m/s. A moving
Earth-Sun RTH target also produced a validated solution; its bounded
300-iteration optimization did not converge and is labeled accordingly.
The final RTH condition uses the actual final epoch.

## Historical control and deliberate differences

A frozen unoptimized first Venus flexibility setup was passed through the
unchanged historical fmincon constraints/objective. The bounded control used
9 feasibility iterations and 150 optimization iterations, exit flags 1 and 0.
It reached 550.3284 m/s and 66.2157 days, with maximum original constraint
violation 1.1832e-10 and independently propagated segment defect 1.0778e-10
in normalized units.

This checks a runnable historical SQP path. It is not a reproduction of the
paper's fixed-50-day IPOPT optimum, a completed historical convergence study
or the full thesis sweep. The canonical path uses coherent scales, explicit
lunar asymptotes and a reduced newly generated catalogue.
[PROVENANCE.md](PROVENANCE.md) lists those changes; these results are not
claimed to be equivalent optima.

## Presentation update, 2026-10-25

The complete suite now passes 34/34 tests (14.07 seconds of test execution).
The five additional presentation tests check rotating DU coordinates, actual
epoch-dependent ECI coordinates and free-vector burn rotations, zero-impulse
plots, and independence of library summaries from native solver iteration
display. With display toggled, compact optimized solutions and physical
validation remain exactly equal in the bounded fixture control.

The actual `step_by_step.m` sections were also exercised with both iteration
budgets temporarily set to zero in an ignored development harness. Candidate
table construction, finite-passage assembly, mesh/guess plotting, solver stage
messages and rejection of the unoptimized guess all completed. This smoke
control does not claim a newly converged cold optimization; the measured full
solve above remains the 2026-10-24 reference. Numerical algorithms and defaults
are unchanged; the example now explicitly enables native iteration output.

Plot styling follows the sibling repository's
`Functions/+rpo2ds/plot_validation.m` and the optimized rotating/inertial plot
sections in `Functions/RPO2DS_transfer.m`: black arcs/circles, blue scaled burns,
Times labels, rotating DU and Earth-centered inertial km. Plot creation passed
for both frames. A new raster-export attempt again stalled in the headless
renderer; no exported-image visual verification is claimed.

## Complete configuration template, 2026-10-25

`examples/config_example.m` replaces the former nested case example. All
numerical fields are explicit and explained; omitted physical constraints are
shown as empty. The RTH target and orbit-file alternatives are commented.
The new and previous configurations were loaded and compared before removing
the old file: numerical options and scientific inputs are identical, accounting
for the now-explicit default `impulse_nodes='all'`.

An additional integration test checks recursive coverage of every numerical
option and loads an unchanged copy from a temporary directory. It verifies
identical orbit, target, constraints, database and effective options, restored
working directory, and that empty initial/final epochs do not become fixed
constraints. The complete suite passes 35/35 tests.

## Orb2DS rename and cleanup, 2026-10-26

After renaming `LibraryName` to `Orb2DS` and removing the historical baseline
from the active tree, all 35 tests passed again (zero failed/incomplete tests,
14.56 seconds of test execution). The MATLAB process started with its standard
path and added only the new `Orb2DS` root. The example configuration loaded the
same 1,986-entry catalogue; no archive or sibling source directory was on path.
All 45 package files, including third-party source/license files, are
byte-identical to the verified snapshot taken before the cleanup. Only naming,
documentation and the configuration header changed in the distributed library.

The local `.dev/archive/2026-10-26` contains the complete original 210-file
snapshot, with every ZIP entry checked by SHA-256. Independent reorganization
checks are retained under `.dev/verification/2026-10-26`. Both are excluded
from Git and are not required to execute the library or its tests.

## First-commit preflight, 2026-10-26

After flattening and renaming the repository to its final path, all 35 tests
passed again from MATLAB's standard path plus the repository root (zero failed
or incomplete tests, 13.49 seconds of test execution). The local report is
`.dev/verification/2026-10-26/github_preflight.json`, excluded from Git.
Git attributes preserve imported numerical and Lambert source/license bytes
so checkout line-ending conversion cannot invalidate their recorded hashes.
The development archive is excluded from the intended version-control set.

## Numerical and presentation limits

Default propagation tolerances are relative 1e-13 and absolute 1e-14, with
normalized solver constraint tolerance 1e-12. They were tightened after
measuring chained drift. Physical acceptance tolerances remain separately
declared. The packaged catalogue retains generation tolerances 1e-12 / 1e-12;
it is not silently regenerated when solver tolerances change.

Reconstruction and plot-object creation/closure passed, including a real
50-line figure. Raster export stalled in the local headless graphics process,
so exported-image appearance has not been visually verified. No export or
automatic figure saving is part of the library API.

Exact/windowed final epochs, MJD2000 and astronomical geometry preparation,
other objectives/backends and the native Python port remain future work.
Unsupported final-epoch requests are explicitly rejected. The contracts accept
a supplied spatial periodic orbit; the integrated case does not establish
coverage or transfer feasibility for arbitrary families.

MATLAB Code Analyzer found no syntax errors in the authored package functions.
Remaining suggestions concern dynamically growing short collections and sparse
Jacobian assignment performance. Imported byte-identical numerical kernels and
third-party files were excluded from that style check. All six imported
source/destination SHA-256 pairs were independently rechecked against the manifest.
