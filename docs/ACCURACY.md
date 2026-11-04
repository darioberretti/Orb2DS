# Physical accuracy

`options.accuracy` defines physical error budgets shared by optimization and
independent validation. Lengths use km, velocities km/s and times local days.
Vector tolerances apply to Euclidean norms, not individual Cartesian axes.

```matlab
cfg.options.accuracy.position_km = 1e-3;    % 1 m.
cfg.options.accuracy.velocity_km_s = 1e-6;  % 1 mm/s.
cfg.options.accuracy.time_days = 1e-7;
cfg.options.accuracy.use_exceptions = false;
```

These are the general defaults. They apply to continuity, departure, target
velocity, radial-event speeds, numerical altitude shortfalls and timing.
The general position/velocity budgets also control chained endpoint closure.

## Optional exceptions

| Field under `accuracy` | Quantity | General budget inherited |
|---|---|---|
| `dynamics.position_km` | Maximum position defect at any shooting junction | `position_km` |
| `dynamics.velocity_km_s` | Velocity defect accounting for the receiving impulse | `velocity_km_s` |
| `departure.position_km` | Pre-burn departure position minus propagated orbit position | `position_km` |
| `departure.velocity_km_s` | Pre-burn departure velocity minus propagated orbit velocity | `velocity_km_s` |
| `target.velocity_km_s` | Achieved minus requested outgoing Earth excess-velocity vector | `velocity_km_s` |
| `periapsis.radial_velocity_km_s` | Absolute Earth/lunar radial speeds at event nodes | `velocity_km_s` |
| `clearance.altitude_km` | Numerical shortfall from Earth/lunar minimum altitude | `position_km` |

All exceptions default to `[]`. An omitted or empty exception inherits its
general budget. With `use_exceptions=false`, specific values are ignored but
retained in saved inputs. With `true`, each nonempty exception applies
`min(general,specific)`: a larger value cannot relax the general requirement.
All nonempty values, including disabled exceptions, must be positive finite
scalars. Unknown fields and invalid types are errors.

```matlab
cfg.options.accuracy.use_exceptions = true;
cfg.options.accuracy.dynamics.position_km = 1e-4; % 10 cm locally.
cfg.options.accuracy.target.velocity_km_s = 1e-7;
```

The general 1 m endpoint budget remains active. `result.accuracy` and
`result.validation.accuracy` report the resolved budgets. The library summary
prints them before solving; original values remain in `result.inputs.options`.

## Optimization and acceptance

Shooting and departure equations remain equalities to zero. Their residuals
and Jacobian rows are scaled by the corresponding physical budgets. Vector
components use budget/sqrt(3), conservatively bounding the full vector norm.
Clearance residuals measure radius shortfall; duration caps use the time budget.

A scaled residual of `1e-9` represents one physical budget. The numerical
`solver.constraint_tolerance` is an advanced stopping threshold on these
residuals. Its default `1e-12` targets 0.001 of each budget. A looser native
threshold can stop before physical accuracy is reached; acceptance always
uses the physical budgets regardless of solver options or stopping status.

The Earth boundary measures outgoing excess-velocity-vector error. Trial-state
evaluation stays real outside the hyperbolic domain, while an energy guard
keeps accepted roots where that vector is exact. Independent validation
recomputes the asymptote from the actual physical state.

`validation.local_is_feasible` reports local checks. Overall `is_feasible`
requires local and chained checks. A locally valid point with excessive
accumulated drift remains a candidate. Local tolerances alone cannot guarantee
chained closure in a sensitive trajectory; inspect errors and integration settings.

## Separate controls

`options.integration` controls propagation in normalized-state units and needs
sufficient precision for the requested budgets. `solver.optimality_tolerance`
concerns objective stationarity. Neither is silently changed by accuracy settings.

Mission minimum altitudes and time caps remain in `problem.constraints`.
Accuracy specifies numerical error around those requirements. The two
`options.validation.orbit_closure_*` fields check the supplied orbit and period;
transfer optimization does not repair those input data.
