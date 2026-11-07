# Supported functionality

The MATLAB namespace `orb2ds` is installed by adding the repository root to the
MATLAB path. Complete copyable configurations are
[`examples/config_database.m`](../examples/config_database.m) for generation and
[`examples/config_transfer.m`](../examples/config_transfer.m) for transfers.
[`examples/workspace/`](../examples/workspace/README.md) is a standalone user-project template.

## Transfer workflow

- Prepare orbit, target, constraints and numerical settings with `load_case`.
- Prepare and authorize explicit saves with `prepare_output`; write selected
  compact MAT variables with `save_output`. See [output behavior](OUTPUT.md).
- Match orbit-Moon encounters and target-dependent Earth legs with `find_legs`.
- Assemble a finite lunar passage and physical arc recipes with `assemble_transfer`.
- Create a shooting mesh with `mesh_transfer`, using a global maximum step and
  one optional event-based refinement interval.
- Inspect the solver initialization with `transcribe_guess`.
- Optimize a supplied compact guess with `optimize_transfer`, or coordinate the
  workflow and deterministic multistart with `find_transfer`.
- Check physical feasibility with `validate_solution`, reconstruct the separate
  trajectory with `reconstruct_trajectory` and display it with `plot_trajectory`.

## Model and controls

The model is spatial Earth-Moon circular restricted three-body dynamics, with
periodic input orbits, normalized orbital phase and explicit km/km/s/day units.
Targets may use Earth-centered inertial or Earth-Sun radial/transverse/normal
coordinates. Initial epoch and phase can be supplied independently or left free.
Waiting, transfer and total duration caps intersect with altitude and impulse
location constraints. Waiting defaults to zero when its cap is omitted or [];
a positive finite `max_wait_time_days` enables it.

Initial-guess construction uses the supplied initial event: phase shortlists,
forward waiting replicas, anchored lunar encounter epochs and intersecting
time caps. RTH legs update the target at arrival. Construction diagnostics
report remaining timing/geometry mismatch before optimization; see
[CONTRACTS.md](CONTRACTS.md#database-and-stage-outputs).

The library generates, saves, validates and reuses schema-1 orbit-Moon databases.
Compact guesses and solutions contain their orbit/model and do not require a
database for optimization or reconstruction.

Optimization supports fmincon with selectable algorithms, and CasADi/IPOPT with
MATLAB callbacks or symbolic CVODES evaluation. The feasibility stage is optional.
Solver verbosity, library summaries and initial-guess plots have separate controls.
See [SOLVERS.md](SOLVERS.md) and [MESH.md](MESH.md).

## Scope and numerical acceptance

Only local-day epochs are supported. Nonempty `final_time_days` requests are
rejected. Astronomical ephemerides and solar gravity are not part of the model.
The implementation language is MATLAB.

Validation tolerances define independent physical acceptance. Separate solver
constraint tolerances inherit them or tighten residual scales during optimization.
Acceptance requires local and chained feasibility; solver
convergence and both physical statuses are reported separately. IPOPT behavior
and integration error can depend on the guess
and numerical settings. Coverage of the example and tests does not guarantee
convergence for every orbit or target. See [VALIDATION.md](VALIDATION.md).
