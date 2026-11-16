# Orb2DS — Orbit-to-Deep-Space Transfer Library

Orb2DS finds spatial Earth-Moon circular restricted three-body transfers from
a supplied periodic orbit, through a lunar encounter, to a prescribed outgoing
Earth excess-velocity vector at Earth perigee.

## Setup and quick start

Add the repository root, which contains `+orb2ds`, to MATLAB's path:

```matlab
addpath('C:\path\to\Orb2DS');
[problem, options] = orb2ds.load_case( ...
    'C:\path\to\Orb2DS\examples\config_transfer.m');
result = orb2ds.find_transfer(problem, options);
```

MATLAB R2025b is the tested environment. fmincon requires Optimization Toolbox.
IPOPT requires a separately installed CasADi MATLAB interface with its IPOPT
plugin; add your CasADi installation root to the path before using that route.
Database generation, reconstruction and plotting use base MATLAB. The Lambert
solver is bundled with its BSD license.

The examples include:

- [basic_usage.m](examples/basic_usage.m): find a transfer, inspect checks and
  plot the final solution or unvalidated candidate.
- [step_by_step.m](examples/step_by_step.m): inspect matching, assembly, mesh
  and NLP initialization before optimization.
- [reuse_guess.m](examples/reuse_guess.m): optimize a reusable guess for a
  changed target.
- [build_database.m](examples/build_database.m): generate or reuse a saved
  orbit-Moon catalogue.
- [workspace/](examples/workspace/README.md): copyable user project with separate
  database/transfer configurations, generation and execution scripts, and data/output folders.

## Configuration

Copy [config_database.m](examples/config_database.m) for catalogue generation or
[config_transfer.m](examples/config_transfer.m) for a transfer. The first defines
the orbit, generation grid, accuracy and output paths; the second consumes a
database and defines the target, physical constraints and transfer numerics.
Together they list supported inputs and settings, including units,
allowed values, defaults and interactions. Relative file paths are resolved
against that configuration file. Rename its function if you rename the file.

Omitted physical constraints stay free, except waiting: an omitted, empty or
zero `max_wait_time_days` disables it. A positive finite value enables waiting
up to that limit. The seed's phase/time origin does not fix departure phase
or epoch, and supplied waiting/flight/total-duration caps all apply. Omitted
numerical settings use `orb2ds.defaults.numerical_options`.
Unknown library settings are rejected. See the [input/output contracts](docs/CONTRACTS.md).

Integration accuracy, initial shooting-node spacing, solver stopping criteria
and physical validation tolerances have explicit settings. See
[validation and constraint tolerances](docs/ACCURACY.md) for acceptance thresholds
and optional tighter solver scales. The [integration and mesh
guide](docs/MESH.md) explains the named refinement anchors, offsets and spacing.
Node count is derived from spacing, arc durations and required event nodes.

Choose `solver.name='fmincon'` or `'ipopt'`. fmincon supports SQP (default),
interior-point, active-set and SQP-legacy. IPOPT supports MATLAB propagation and
Jacobians or symbolic CasADi/CVODES evaluation. The feasibility stage is optional,
and `options.n_starts` selects deterministic multistart over ranked candidates.
IPOPT routes are experimental; inspect physical checks for the selected problem.
See [solver setup and options](docs/SOLVERS.md).

`output.display` controls library summaries; `solver.display` controls native
solver output. `output.plot_initial_guess` and `output.plot_nlp_guess` select
physical-leg and shooting-node previews independently. Final plots in the basic
and step-by-step examples explicitly label an unvalidated candidate.
See the [examples guide](examples/README.md) for the individual script stages.
Console sections separate solver termination, physical acceptance and returned
data. Use `orb2ds.node_table(result)` for all node impulses in m/s and
`orb2ds.print_result(result)` to inspect stored validation again. See
[console output and inspection](docs/LOGGING.md).

## Direct scientific stages

```matlab
candidates = orb2ds.find_legs(problem, options);
transfer = orb2ds.assemble_transfer(problem, candidates(1), options);
seed = orb2ds.mesh_transfer(problem, transfer, options);
result = orb2ds.optimize_transfer(problem, seed, options);
```

Check that candidates and assembly are nonempty before meshing.
`build_initial_guess` composes matching, assembly and meshing; `find_transfer`
coordinates those stages with optimization and optional multistart.

`optimize_transfer` also accepts a compatible compact solution as a guess for
another target or constraint set. It preserves node count/order and needs no
database. Each call validates the result against the current problem.

## Reusable database

The bundled catalogue contains 720 sampled impulsive departures and 1,986 lunar
entries for the orbit in `config_transfer.m`. Generate a catalogue for another
orbit or sampling grid with:

```matlab
database = orb2ds.build_orbit_moon_database(orbit, 'my_catalogue.mat', options);
problem.database = database;
```

An existing filename is reused only when orbit, model, grid and integration
settings match. The builder raises an error for a mismatch and does not overwrite
the file. [build_database.m](examples/build_database.m) demonstrates explicit
generation and reuse using config_database.m and a separate archive under
`databases/` beside that configuration. It also exports the orbit for configurations using
`files.orbit`. The [copyable workspace](examples/workspace/README.md) connects
generation and transfer through those explicit files.

## Results and reconstruction

By default Orb2DS prioritizes convergent delta-v solves, compares their costs,
and stores the selected record in `result.candidate`. Set
`options.validation.enabled = true` to check local continuity and propagate
the trajectory continuously after solving. Set `options.validation.require_pass = true`
to run those checks and give physically validated records selection priority.
A record passing both checks is stored in `result.solution`, and
`result.validation` contains the physical diagnostics when checks run.
`result.constraint_tolerances` gives the separate solver residual scales.
See [validation and tolerance meanings](docs/VALIDATION.md).

```matlab
record = result.solution;
if isempty(record)
    record = result.candidate;
end
if ~isempty(record)
    trajectory = orb2ds.reconstruct_trajectory(record);
    orb2ds.plot_trajectory(trajectory, struct('show_defects', true));
end
```

The compact record includes everything needed for reconstruction without the
database. Dense samples and figures are separate transient objects and are
never embedded in results. Save results or figures explicitly when needed.
The workspace saves compact results to `Orb2DS_output/` beside its configuration
by default. Choose another directory in `cfg.output.directory`; missing folders
are created on request. `overwrite_without_prompt=false` asks before replacing
existing results, before numerical work starts. Set it to true for authorized
unattended replacements. See [output preparation and saving](docs/OUTPUT.md).

## Tests and scope

```matlab
checks = runtests(fullfile(pwd, 'tests'));
assert(~any([checks.Failed]));
```

Add CasADi first to exercise the IPOPT tests; otherwise those tests report a
skip. Read [supported functionality](docs/IMPLEMENTATION_STATUS.md) for the
model and API scope. Epochs use local days; nonempty `final_time_days` requests
are unsupported. The supplied orbit and tests do not guarantee convergence for
every periodic orbit or target.

## License and citation

Project code, documentation and bundled example/test data use the
[MIT License](LICENSE), with separate notices for third-party material.
FEX-Lambert by Rody Oldenhuis retains its
[BSD-2-Clause license](+orb2ds/+thirdparty/+fexlambert/License.txt).
See [attribution and bundled data](docs/PROVENANCE.md).

If you use Orb2DS in research, cite the software using [CITATION.cff](CITATION.cff)
or GitHub's **Cite this repository** option.
