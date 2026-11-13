# Console output and result inspection

Library messages use `[Orb2DS]` headings for matching, initial guesses, mesh,
optimization, validation, databases and output files. Repeated progress uses
columns. With strict selection, the automatic report shows values, physical
limits and individual `PASS`/`FAIL` verdicts together.

`options.output.display` enables these automatic messages. It does not enable
or disable figures. `options.solver.display` independently selects native solver
output (`off`, `final`, `iter`, `iter-detailed`). Native iteration tables retain
the solver's format, under the corresponding feasibility/minimization heading.
Solver termination is reported separately from physical acceptance.
Output preparation/saving uses `prepare_output`'s `display` setting; the
workspace passes `options.output.display` to it.

`Solver constraint tolerances` shows the native constraint tolerance after
applying solver-specific overrides. The table gives its physical equivalents
under Orb2DS residual scaling in km, m/s and seconds. For vector residuals the
equivalents refer to the vector norm. The duration row appears when a duration
cap is active. The native test is identified as absolute or relative. For
relative fmincon tests these are reference values at the configured threshold.
[MathWorks tolerance details](https://www.mathworks.com/help/optim/ug/tolerance-details.html)
and [IPOPT termination options](https://coin-or.github.io/Ipopt/OPTIONS.html#OPT_constr_viol_tol)
describe the native tests.

The final report separates multiple-shooting checks from continuous propagation.
Position residuals are displayed in metres and velocity residuals in mm/s; their
limits come from the stored validation tolerances. Altitudes remain in km and
include the required minimum and allowed numerical shortfall. Stored record and
configuration units remain km, km/s and days. Display conversions do not change
validation thresholds or solver settings.

With `validation.require_pass=false` (default), the automatic report shows the
transfer summary. The physical acceptance thresholds appear when
`validation.require_pass=true`. A convergent selected solve outside the physical criteria
reports `Transfer found`. A stopped solve with such a point reports
`Candidate available`. The selected record, residuals and physical verdicts are
stored in `result`. Call `orb2ds.print_result(result)` for the full physical
validation and continuous propagation report in either mode.

## Find the data

The transfer examples print a `Result data` block identifying their in-memory
variable and selected record. Saving through `save_output` prints the exact MAT
path and variable names. For a MAT variable named `result`, it also prints the
record path and the commands to load, inspect and tabulate that result.

The workspace example saves the entire result even when physical validation
fails. The other transfer examples keep results in memory. Scientific functions
never save automatically; see [output files](OUTPUT.md).

## Inspect all node impulses

```matlab
nodes = orb2ds.node_table(result);
openvar('nodes');
```

The table contains every node, including zero burns: node index, local epoch in
days, three impulse components in m/s and the impulse magnitude in m/s. Components
use barycentric rotating axes. An accepted solution is selected when available;
otherwise its unvalidated candidate is selected. A result with neither returns
an empty table. A compact seed or transfer record can also be passed directly.
The table is derived on request and is not added to results or saved implicitly.

## Inspect validation again

```matlab
load('C:\my_project\Orb2DS_output\transfer_result.mat', 'result');
orb2ds.print_result(result);
```

`print_result` displays the stored diagnostics and vector components. It performs
no propagation or optimization and writes no files. This explicit inspection
prints even when automatic output was disabled during the run. Use
`validate_solution` when you need a new physical verification with current inputs
or different integration settings.
