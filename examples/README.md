# Examples

Add the library root to MATLAB's path. Each demonstration also resolves that
root from its own location. Optimization requires Optimization Toolbox.

1. Run `basic_usage.m` for the complete method, physical result inspection and
   separately reconstructed plot.
2. Run `step_by_step.m` to inspect matching, assembly and mesh before optimization.
3. Run `reuse_guess.m` to reuse an initialization for a changed target.

The scripts are independent usage demonstrations. The complete configuration
reference is [config_example.m](config_example.m), directly in this folder.
It lists every supported input and numerical option, with units, interactions
and commented mutually exclusive alternatives. Copy it wherever convenient,
edit its inputs and file references, then call it from your own script:

```matlab
[problem, options] = orb2ds.load_case('C:\my_project\config_example.m');
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

All numerical fields are explicit in the template; you may remove any you want
to inherit from `+orb2ds/+defaults/numerical_options.m`. Empty physical constraints
remain free; numerical [] is invalid. A model or orbit change requires a matching
database rather than relabeling this one. Reconstruction/plotting settings are
also documented at the end as separate copyable calls, outside the solver cfg.

The Venus target vector comes from the thesis target input. The example's model,
catalogue and numerical sampling are explicit new calculations. Solver stopping
status, multiple-shooting feasibility and independently chained closure must be
read separately; a best validated candidate need not have optimizer convergence
or be the global optimum. See `../docs/VALIDATION.md` for measured results.

Nothing saves transfer results or figures automatically. Save `result` or its
self-contained `solution` explicitly if needed. Dense trajectory samples are
returned only by `reconstruct_trajectory` and never inserted into a result.

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
4. `mesh_transfer` creates the shooting nodes and burn initialization. Change
   `cfg.options.mesh.max_step_days` in the case for a different maximum spacing.
   The initial-guess plot preserves patch defects; it is not a feasible transfer
   claim. `show_initial_guess=false` skips that preview.
5. `optimize_transfer` moves the supplied nodes, burns and unconstrained timing
   quantities. It first seeks feasibility with zero objective, then minimizes
   total delta-v. Removing `problem.database` demonstrates that optimization
   needs only the orbit, current target/constraints and compact guess.
6. Reconstruction creates a separate trajectory for the validated solution;
   the script also prints the optimized timing and chained propagation check.

Candidates are ordered by estimated **Earth-perigee burn**, following the thesis
matching algorithm. For each Earth leg the matcher chooses the closest compatible
incoming lunar speed. This ranking is not total optimized cost. Candidate 2 can
converge better than candidate 1, fail assembly or converge to a different local
solution. Candidate indices are local to the returned search and can change when
the target, catalogue or search sampling changes. Several candidates may refer
to the same database row with different Earth-side geometry.

The explicit script optimizes one candidate even if `n_starts` is larger than 1.
Use `find_transfer` with `options.n_starts` for automatic multistart and validated
cost selection. No automatic candidate substitution occurs in the explicit script.

## Command-window output

The two existing display settings have independent responsibilities:

```matlab
cfg.options.output.display = true;   % Library search, stages and physical summary.
cfg.options.solver.display = 'iter';  % Native fmincon iteration table.
```

The supplied Venus case now enables both. Generic library defaults remain
library summaries on and native solver display off. Choose settings directly:

| Desired library/solver output | `output.display` | `solver.display` |
|---|---|---|
| Silent library and solver | `false` | `'off'` |
| Search/stage/physical summaries | `true` | `'off'` |
| Summaries and solver stopping reasons | `true` | `'final'` |
| Summaries and every solver iteration | `true` | `'iter'` |
| Iterations with detailed stopping information | `true` | `'iter-detailed'` |

These are combinations of existing settings, not named execution modes.
The script's explicit `disp`/`fprintf` inspections are separate from automatic
library output and remain visible when library messages are disabled.

The first solver table has `f(x)=0` by construction: watch feasibility there.
In the second table, `f(x)` is normalized total delta-v; the stage header prints
the factor converting it to m/s. `Feasibility` reports maximum normalized
constraint violation, and first-order optimality concerns solver convergence.
Neither replaces the final independent physical residuals in km and km/s.
The solver's native output can be enabled even with library summaries disabled.
See MathWorks' [iteration table definitions](https://www.mathworks.com/help/optim/ug/iterative-display.html).

## Thesis-style figures

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
