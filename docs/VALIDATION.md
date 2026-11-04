# Numerical validation

Read `result.status`, solver termination, `result.validation.local_is_feasible`
and `result.validation.chained` together. `result.solution` requires both local
and continuously chained physical acceptance. `result.accuracy` reports the
physical budgets actually applied.

## Run the tests

From the repository root:

```matlab
addpath(pwd);
checks = runtests(fullfile(pwd, 'tests'));
disp(table(checks));
assert(~any([checks.Failed]));
```

Tests cover model scales, orbit closure, frames, analytic sensitivities, impulse
maps, initial phase/epoch cases, timing caps, database reuse, matching/assembly,
mesh refinement, solver adapters, reconstruction and plotting objects.
Accuracy tests check exception precedence, vector norms, actual outgoing-vector
residuals, nonhyperbolic trials, shared derivatives and chained acceptance.
Add CasADi to the path for its tests; otherwise those tests report a skip.
fmincon tests need Optimization Toolbox. Raster export is outside this suite.

## Physical checks

The validator repropagates segments with ode113, measures junction defects,
compares departure with the supplied orbit and recomputes the achieved Earth
excess velocity. It locates interior radial extrema for body clearance, checks
periapsis speeds/accelerations, timing caps and impulse locations.

General budgets and optional tighter exceptions are under `options.accuracy`.
Vector errors use Euclidean norms. [ACCURACY.md](ACCURACY.md) lists every setting,
unit and precedence rule.

`options.validation.orbit_closure_position_km` and `orbit_closure_velocity_km_s`
check one-period input-orbit closure, with defaults 0.01 km and 1e-7 km/s.
The transfer optimizer does not adjust the input reference state or period.

## Continuously chained propagation

Starting at the first post-impulse state, the validator propagates through all
segments and applies subsequent impulses without resetting to stored nodes.
It checks endpoint position/velocity against the general budgets and recomputes
clearance and outgoing-vector error using their resolved budgets.

`local_is_feasible` reports junction/boundary checks. `chained.is_feasible`
requires those plus chained closure, target and clearance checks. Overall
`is_feasible` and `checks.chained` include the chained requirement. If no stage
candidate passes, `result.candidate` retains a rejected record when available.
The examples plot it with an explicit unvalidated label.

## Numerical interpretation

Solver residuals and Jacobians use the same physical budgets as the validator.
The numerical stopping threshold, objective optimality and integration accuracy
have distinct meanings; see [SOLVERS.md](SOLVERS.md) and
[integration settings](MESH.md#integration-accuracy).

Equal tolerance numbers in CVODES and ode113 do not guarantee equal endpoint
errors. Sensitive trajectories can accumulate small local defects. Solver
convergence cannot replace physical reconstruction, and solver overrides do
not change physical acceptance budgets.

Different guesses and backends can reach different local minima or fail.
An exhausted search does not prove that a transfer is impossible. The supplied
orbit and tests do not guarantee convergence for every orbit family.
