# Examples

Add the library root to MATLAB's path. The four scripts directly in this folder
also resolve that root from their own location. fmincon requires Optimization
Toolbox; IPOPT requires a separately installed CasADi MATLAB interface with its
IPOPT plugin.

1. Run `basic_usage.m` for the complete method, physical result inspection and
   separately reconstructed plot.
2. Run `step_by_step.m` to inspect matching, assembly and mesh before optimization.
3. Run `reuse_guess.m` to reuse an initialization for a changed target.
4. Run `build_database.m` to explicitly generate and save a reusable catalogue,
   or reuse its existing compatible archive. This requires only base MATLAB.

The scripts are independent usage demonstrations. Two separate configuration
references list inputs, units, defaults and alternatives:

- [config_database.m](config_database.m): orbit, generation grid, integration,
  closure checks, progress and database/orbit output paths.
- [config_transfer.m](config_transfer.m): orbit/database inputs, target, physical
  constraints, matching, mesh, integration, optimization and validation.

For a ready-to-copy project containing both configurations and its own generated
data folders, use [workspace/](workspace/README.md). It can live outside Orb2DS
and calls only the installed library. It defines the orbit once, in the database
configuration, and shares its exported descriptor with the transfer configuration.

Copy the full transfer reference wherever convenient, edit its inputs and file
references, then call it from your own script:

```matlab
[problem, options] = orb2ds.load_case('C:\my_project\config_transfer.m');
result = orb2ds.find_transfer(problem, options);
```

If you rename the file, rename its MATLAB function to match. No prescribed case
directory or runner is required. The unchanged copy locates the packaged database
from the installed library, independently of its own directory. When replacing
file references with your own relative paths, they are resolved against the
configuration file, not the calling script or current working directory.

The example uses the small coherent catalogue in `data/`, with 12 phases,
five impulse magnitudes, 12 in-plane directions and a 50-day generation horizon.
Those are search/data-generation bounds; only `problem.constraints` limits the
optimized physical transfer. Initial epoch and phase are free in the example.

All numerical fields used for transfers are explicit in their template; remove
any to inherit from `+orb2ds/+defaults/numerical_options.m`. Empty physical constraints
remain free except `max_wait_time_days`: omitted, [] or 0 disables waiting;
a positive finite value enables it up to that limit. Numerical [] is invalid
except for optional solver constraint tolerances, which inherit validation
thresholds. A model or orbit change requires a matching database; relabeling
this one does not make it compatible. Reconstruction/plotting settings are
also documented at the end as separate copyable calls, outside the solver cfg.

The example configuration declares its target vector, model and numerical settings.
The catalogue embeds its orbit and generation settings. Solver stopping
status, multiple-shooting feasibility and independently chained closure must be
read separately; a best validated candidate need not have optimizer convergence
or be the global optimum. See `../docs/VALIDATION.md` for measured results.

The three transfer demonstrations directly in examples/ do not save results or
figures. The workspace's run_transfer.m explicitly saves its compact result.
Dense trajectory samples are returned only by `reconstruct_trajectory` and never
inserted into a result.

## Validation and solver constraint tolerances

Set `cfg.options.validation.position_km`, `velocity_km_s` and `time_days` for
independent physical acceptance. The following config section lists optional
`cfg.options.solver.constraint_tolerances`: [] inherits validation, while a
nonempty value immediately tightens only the solver residual scale. No enable
flag is needed. `result.validation.tolerances` reports acceptance thresholds;
`result.constraint_tolerances` reports resolved solver scales. See
[ACCURACY.md](../docs/ACCURACY.md) for units and inheritance rules.

## Creating a database

Run `build_database.m`. It reads `config_database.m` and calls
`orb2ds.build_orbit_moon_database(cfg.orbit, cfg.output.database, cfg.options)`.
The transfer configuration is not read. You can replace the inline orbit in
the database configuration with a descriptor loaded explicitly from your MAT.

The configuration provides a small explicit grid of 12 phases, five impulse
magnitudes, 12 azimuths and one elevation, with a 50-day horizon. All generation
settings remain in the config. Generic builder defaults remain 50 phases,
10 magnitudes, 100 azimuths and an 85-day horizon.

The script saves `databases/orbit_moon_generated.mat` and exports the
same orbit to `databases/orbit.mat` beside its configuration, outside version control.
On a second run the builder checks the same orbit, grid and integration settings
and reuses the file. With different settings it raises an error; choose a new
output filename explicitly. An identical standalone orbit MAT is reused without
rewriting; another descriptor requires another filename. The packaged `data/orbit_moon_example.mat` is
not the generation destination.

To use the generated catalogue in a transfer, set `cfg.files.database` in your
transfer configuration to that archive's absolute path, or a path relative to
your config. Set `cfg.files.orbit` to the exported orbit MAT and remove the
inline `cfg.orbit`; only one orbit input is allowed. The workspace already
uses this arrangement. If already loaded, assign `problem.database = database`
directly instead.

## Saving results in a user project

Copy workspace/ outside the library installation before using its saving script.
Its transfer configuration has a separate `cfg.output` block: directory
`Orb2DS_output` relative to that file, filename `transfer_result.mat`, and
`overwrite_without_prompt=false`. `options.output` still controls messages and
initial-guess plots; it does not select output files.

The script calls `prepare_output` before matching/optimization, creates missing
folders, and asks once about existing files. Declining stops the script. Batch
execution requires the overwrite flag to be true for an existing file. The
final `save_output` retains the old result until the new MAT write completes.
See [output preparation and saving](../docs/OUTPUT.md) for the direct API.

## Reading step_by_step.m

The numbered editor sections can be executed one at a time:

1. `load_case` reads the case, loads the shared catalogue and resolves numerical
   defaults. Change the orbit, target, constraints and numerical options in a
   copied case function. Preparation runs no search or optimization.
2. `find_legs` searches Earth-side Lambert legs and matches each against compatible
   orbit-Moon entries. It returns a ranked collection, not optimized solutions.
   The printed table exposes candidate rank, database row, departure phase,
   the two estimated endpoint burns and the lunar speed mismatch.
3. `candidate_index` chooses one returned match. Assembly reconstructs its finite
   lunar passage and physical event timeline. No database row is selected directly.
   The first plot shows the assembled arcs without shooting nodes.
4. `mesh_transfer` creates nodes and returns a spacing summary. The configuration
   controls the global maximum step and local refinement from before lunar
   periapsis through Earth periapsis.
5. `transcribe_guess` exposes the exact initialization after NLP timing,
   impulse and bounds handling. Its CR3BP reconstruction is the second plot,
   with shooting nodes and dashed position defects. Stop here to inspect both
   guesses without solving.
6. `optimize_transfer` moves nodes, burns and unconstrained timing quantities,
   optionally seeking zero-objective
   feasibility before minimizing delta-v. Removing `problem.database`
   demonstrates that optimization needs only the current physical problem
   and compact guess. The explicit preview disables the duplicate automatic one.
7. Reconstruction creates a separate trajectory for the validated solution or,
   if validation fails, the final candidate. The plot name and title report its
   acceptance status. The script also prints failed checks and chained diagnostics.

Candidates are ordered by estimated **Earth-perigee burn**. For each Earth leg
the matcher chooses the closest compatible
incoming lunar speed. This ranking is not total optimized cost. Candidate 2 can
converge better than candidate 1, fail assembly or converge to a different local
solution. Candidate indices are local to the returned search and can change when
the target, catalogue or search sampling changes. Several candidates may refer
to the same database row with different Earth-side geometry.

The explicit script optimizes one candidate even if `n_starts` is larger than 1.
Use `find_transfer` with `options.n_starts` for automatic multistart. Selection
prioritizes convergent delta-v solves by default. Set
`options.validation.enabled=true` to run post-solve physical checks, or
`options.validation.require_pass=true` to also prioritize validated cost. The
explicit script processes only the candidate selected in its editor section.

Set `cfg.options.output.plot_initial_guess` and `plot_nlp_guess` independently
to show or hide the two initial views. Both default to false in the library
and are enabled in the example. Plot flags are independent of verbosity.
See [mesh settings and guess inspection](../docs/MESH.md) for the full contract.

## Command-window output

The two display settings have independent responsibilities:

```matlab
cfg.options.output.display = true;   % Library search, stages and physical summary.
cfg.options.solver.display = 'iter';  % Selected solver's native iteration table.
```

The supplied example enables both. Generic library defaults are
library summaries on and native solver display off. Choose settings directly:

| Desired library/solver output | `output.display` | `solver.display` |
|---|---|---|
| Silent library and solver | `false` | `'off'` |
| Search/stage/physical summaries | `true` | `'off'` |
| Summaries and solver stopping reasons | `true` | `'final'` |
| Summaries and every solver iteration | `true` | `'iter'` |
| Iterations with detailed stopping information | `true` | `'iter-detailed'` |

Library messages have `[Orb2DS]` phase headings, aligned progress columns and
value/limit validation rows when strict selection is enabled. The
`step_by_step` candidate table remains visible when automatic output is off.
The other examples use the library summary and a compact data-location block,
without repeating raw result structures.

The first solver table has `f(x)=0` by construction: watch feasibility there.
In the second table, `f(x)` is normalized total delta-v; the stage header prints
the factor converting it to m/s. `Feasibility` reports maximum normalized
constraint violation, and first-order optimality concerns solver convergence.
Neither replaces independent physical validation. The final report displays
position errors in metres and velocity errors in mm/s, with the corresponding
limits; stored data and configuration remain in km and km/s.
The solver's native output can be enabled even with library summaries disabled.
See MathWorks' [iteration table definitions](https://www.mathworks.com/help/optim/ug/iterative-display.html).

The data-location block identifies `result.solution` or `result.candidate` and,
when saving, the actual MAT file. Use `nodes = orb2ds.node_table(result)` and
`openvar('nodes')` to inspect every impulse, including zero burns. Use
`orb2ds.print_result(result)` to display stored validation again, without a new
propagation. See [console output and inspection](../docs/LOGGING.md).

## Choosing the optimizer

The complete settings are in `config_transfer.m`. Keep `solver.name='fmincon'`
and choose `solver.fmincon.algorithm` for another MATLAB algorithm. To use IPOPT,
first add your installed CasADi directory to the path in your calling script:

```matlab
addpath('C:\path\to\casadi');
[problem, options] = orb2ds.load_case('C:\path\to\my_config.m');
options.solver.name = 'ipopt';
options.solver.evaluation = 'matlab'; % Or 'casadi' for symbolic CVODES evaluation.
result = orb2ds.find_transfer(problem, options);
```

Native options such as `solver.ipopt.mu_strategy='adaptive'` are optional and
override common settings. IPOPT's table uses its own feasibility/dual/barrier
columns. See [solver settings](../docs/SOLVERS.md) for mappings and differences.

## Figure settings

The default plot has black arcs, black shooting-node circles, blue scaled impulse
arrows, blue/red departure/arrival markers, grid, equal spatial scale and Times
labels. It uses an XY view in rotating barycentric DU. All Z coordinates remain
in the plot and can be inspected by rotation or an explicit 3D view:

```matlab
orb2ds.plot_trajectory(trajectory, struct('view', [-37.5, 30]));
orb2ds.plot_trajectory(trajectory, struct('frame', 'eci')); % Earth-centered km.
```

The ECI view transforms each point at its actual epoch and draws the circular
Moon path. Impulses rotate as free vectors, with no frame-velocity offset.
`show_nodes`, `show_impulses` and `impulse_scale` control the overlays.
The default longest arrow spans 0.38 of the trajectory extent, preserving
relative burn magnitudes; its plotted length is not a physical displacement.
Arrows below 1e-4 of the largest burn are hidden. Set `show_impulses=false` or
`impulse_scale=0` to hide them. Figure settings do not alter the scientific result.
