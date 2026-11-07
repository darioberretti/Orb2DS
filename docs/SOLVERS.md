# Optimization solvers

The same spatial shooting problem with physical-budget residual scaling supports three routes:

| `solver.name` | `solver.evaluation` | Numerical evaluation |
|---|---|---|
| `'fmincon'` (default) | `'matlab'` (default) | ode113, analytic STMs and local complex-step derivatives |
| `'ipopt'` | `'matlab'` | The same MATLAB functions and Jacobians, connected through CasADi callbacks |
| `'ipopt'` | `'casadi'` | Symbolic equations, CVODES flows and their sensitivities |

The IPOPT routes are experimental. Inspect local physical checks and chained
closure for your problem; see [numerical validation](VALIDATION.md).

All routes use the same variable layout, physical constraints, normalization,
mesh and Oshima impulse charts. Both stages use the selected route: optional
zero-objective feasibility followed by delta-v minimization, initialized with
the preceding stage's primal vector. Dual-multiplier warm starts are not supplied.
`optimize_transfer` never remeshes or regenerates a database.

For reuse of a good solution with a nearby target, consider setting
`solver.run_feasibility=false` explicitly. A zero-objective stage may move to
a much more expensive feasible point because it has no incentive to retain
the initial delta-v. This setting is never changed automatically.

## Dependencies and setup

fmincon requires Optimization Toolbox. IPOPT requires the CasADi MATLAB interface
with its IPOPT plugin, installed separately; add that installation's root to the
MATLAB path before finding or optimizing transfers. Orb2DS neither downloads nor
bundles CasADi, changes its installation, nor falls back to another solver.
Solver availability is checked before the high-level leg search. Config loading
and database generation do not require either optimizer.

```matlab
addpath('C:\path\to\Orb2DS');
addpath('C:\path\to\casadi');
[problem, options] = orb2ds.load_case('C:\path\to\config_transfer.m');
options.solver.name = 'ipopt';
options.solver.evaluation = 'casadi';
result = orb2ds.find_transfer(problem, options);
```

## Algorithms and native options

`solver.fmincon.algorithm` accepts `'sqp'`, `'interior-point'`, `'active-set'`
and `'sqp-legacy'`. Trust-region-reflective is excluded because the NLP has
nonlinear constraints. Use `solver.fmincon.options` for native `optimoptions`
names/values, `solver.ipopt` for IPOPT options, `solver.casadi` for CasADi
`nlpsol` options, and `solver.cvodes` for symbolic-route integrator options.

```matlab
cfg.options.solver.fmincon.options.MaxIterations = 400;
cfg.options.solver.ipopt.mu_strategy = 'adaptive';
cfg.options.solver.ipopt.max_iter = 400;
cfg.options.solver.casadi.print_time = true;
cfg.options.solver.cvodes.max_num_steps = 200000;
```

Native options explicitly supplied in an active block override the common
settings and adapter defaults. Consequently native `MaxIterations` or `max_iter`
overrides the budgets of **both** stages. Inactive blocks remain in the saved
configuration but are not applied. Unknown library options fail immediately;
native spelling and compatibility are checked by MATLAB/CasADi/IPOPT when used.
Only serializable data are accepted; user callbacks and runtime objects are
excluded. Orb2DS owns fmincon's derivative/callback interfaces.

The adapter records effective options separately for each stage. Native IPOPT
options belong in `solver.ipopt`, not nested inside `solver.casadi.ipopt`.
CVODES overrides affect symbolic optimization, not independent validation or
database generation. Relative and absolute integration tolerances otherwise
come from `options.integration` in both routes. Equal tolerance numbers do not
imply equal endpoint errors across ode113 and CVODES.

## Common setting mappings

| Common setting | fmincon | IPOPT |
|---|---|---|
| `run_feasibility` | Enable stage 1 | Enable stage 1 |
| `max_iterations_feasibility` / `max_iterations` | Per-stage `MaxIterations` | Per-stage `max_iter` |
| `constraint_tolerance` | `ConstraintTolerance` | `constr_viol_tol` |
| `optimality_tolerance` | `OptimalityTolerance` | `tol`, a scaled combined NLP-error criterion |
| `step_tolerance` | `StepTolerance` | Not applied; listed in stage diagnostics |
| `max_function_evaluations` | `MaxFunctionEvaluations` | Not applied; listed in stage diagnostics |
| `minimum_segment_days` | Shared duration lower bound | Shared duration lower bound |

The tolerance mappings are not mathematical equivalences. IPOPT also uses native
dual-infeasibility and complementarity conditions, which can be set in its block.
Shared physical validation tolerances always retain their declared km/km/s/day
meanings regardless of the selected solver.

Both IPOPT routes default to `hessian_approximation='limited-memory'`,
`acceptable_iter=0`, `bound_relax_factor=0` and `option_file_name=''`. This avoids
the successive-acceptable-iterations shortcut, bound relaxation and a working-directory
`ipopt.opt` override. Native options can change these choices. Exact Hessians
require the symbolic route; MATLAB callbacks provide only first derivatives.
IPOPT's normal bound-push initialization can move a supplied feasible guess;
`bound_push` and `bound_frac` are native controls, not validation tolerances.

Symbolic CVODES flows default to forward sensitivities (`ad_weight=0`,
`enable_reverse=false`) to avoid backward reintegration around close passages.
These are explicit integrator settings and can be overridden in `solver.cvodes`.

MATLAB callback Jacobians have fixed structural sparsity, including entries that
vanish for a planar or zero-burn seed. Values and Jacobians at the same vector
share a cached STM propagation. Failed trial integrations return nonfinite
residuals so IPOPT can reject the trial and reduce its line-search step; unrelated
MATLAB exceptions still propagate. Evaluation warnings can be enabled with
`solver.casadi.show_eval_warnings=true`.

## Output and acceptance

`output.display` controls library messages independently of `solver.display`.
For IPOPT, `'off'` maps to print level 0, `'final'` to level 0 plus a compact
native status line, `'iter'` to 5 and `'iter-detailed'` to 7. Native `print_level`
and `print_time` overrides retain priority. Neither native iteration histories
nor callback objects are saved in `result`.

Stage metadata includes solver/evaluation, effective native settings, iterations
and stopping information. CasADi version, final primal/dual infeasibility and
barrier parameter (when available), and call counters are stored
for IPOPT; its graph and solver construction times are separate from solve time.
fmincon metadata includes MATLAB and Optimization Toolbox versions.

IPOPT statuses retain their native text. `Solve_Succeeded` sets the shared
convergence flag; `Solved_To_Acceptable_Level` has a separate acceptable flag.
Iteration/time limits, small steps and errors do not imply optimization
convergence. Numeric IPOPT exit flags are adapter categories, not fmincon codes.
A physically valid point can be returned without optimization convergence.

Every returned stage candidate is independently checked with the MATLAB/ode113
validator, including achieved target, segment closure, body clearance and chained
propagation. Neither solver success nor a lower objective replaces those checks.
With `output.display=true`, the summary reports failed physical checks and
the position/velocity thresholds for both segment closure and orbit departure.
The basic and step-by-step examples also plot a rejected final candidate with
an explicit unvalidated label; physical acceptance and result fields do not change.

Residuals are scaled with the resolved `options.solver.constraint_tolerances`.
Empty settings inherit the corresponding `options.validation` tolerance;
nonempty values can only tighten the solver scale and leave validation unchanged.
One effective tolerance corresponds to a scaled residual of `1e-9`. The default
constraint threshold `1e-12` targets 0.001 of each tolerance, leaving margin for
integration and accumulation errors. Vector components use tolerance/sqrt(3).
Native stopping overrides can affect convergence but do not change physical
acceptance. See [validation and constraint tolerances](ACCURACY.md).

The Earth boundary compares the actual outgoing excess-velocity vector in
its hyperbolic domain. A real, twice differentiable extension permits trial
states outside that domain; an energy inequality retains squared excess speed
above one percent of the requested squared speed. Independent validation
recomputes the physical asymptote and requires continuously chained closure.
Integration differences between CVODES and ode113 can still affect acceptance.
Different routes can reach different local minima or fail on different guesses;
no solver is assumed faster or more robust without measurement.

References: [CasADi documentation](https://web.casadi.org/docs/),
[IPOPT options](https://coin-or.github.io/Ipopt/OPTIONS.html),
[MathWorks algorithm selection](https://www.mathworks.com/help/optim/ug/choosing-the-algorithm.html).
