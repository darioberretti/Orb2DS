# Validation and constraint tolerances

`options.validation` defines the physical tolerances for independent checks
after optimization. `options.solver.constraint_tolerances` controls the physical
scales of constraint residuals during optimization. Lengths use km, velocities
km/s and times local days. Vector tolerances apply to Euclidean norms.

## Independent validation

```matlab
cfg.options.validation.position_km = 1e-3;    % 1 m.
cfg.options.validation.velocity_km_s = 1e-6;  % 1 mm/s.
cfg.options.validation.time_days = 1e-7;
cfg.options.validation.orbit_closure_position_km = 0.01;
cfg.options.validation.orbit_closure_velocity_km_s = 1e-7;
```

These are the defaults. The position tolerance applies to segment defects,
departure position, chained endpoint closure and numerical shortfalls from
minimum altitudes. The velocity tolerance applies to segment defects, departure
velocity, chained endpoint closure, outgoing excess-velocity-vector error,
periapsis radial speeds and the impulse-location policy. The time tolerance
covers phase/epoch couplings and waiting, transfer and total duration caps.

The two `orbit_closure_*` values check the supplied periodic orbit over one
period. Transfer optimization does not repair its reference state or period.
Mission minimum altitudes and time caps remain in `problem.constraints`;
validation tolerances specify the numerical error allowed around them.

Validation is always required for a solution to be accepted. Its thresholds are
reported in `result.validation.tolerances`. Changing solver constraint tolerances
does not change these thresholds or the independently propagated trajectory.

## Solver constraint tolerances

Every field below defaults to `[]`, which inherits the corresponding validation
tolerance. A supplied positive finite scalar applies immediately, without an
enable flag. The effective value is `min(validation,supplied)`, so a solver
setting can only tighten the inherited tolerance.

| Field under `solver.constraint_tolerances` | Residual | Inherited validation field |
|---|---|---|
| `dynamics.position_km` | Position defect at each shooting junction | `position_km` |
| `dynamics.velocity_km_s` | Velocity defect accounting for the receiving impulse | `velocity_km_s` |
| `departure.position_km` | Pre-burn departure minus propagated orbit position | `position_km` |
| `departure.velocity_km_s` | Pre-burn departure minus propagated orbit velocity | `velocity_km_s` |
| `target.velocity_km_s` | Outgoing Earth excess-velocity-vector error | `velocity_km_s` |
| `periapsis.radial_velocity_km_s` | Earth/lunar radial speed at event nodes | `velocity_km_s` |
| `clearance.altitude_km` | Radius shortfall at nodes | `position_km` |
| `time_days` | Timing equalities and duration caps | `time_days` |

```matlab
cfg.options.solver.constraint_tolerances.dynamics.position_km = 1e-4;
cfg.options.solver.constraint_tolerances.target.velocity_km_s = 1e-7;
```

This requests tighter local continuity and target residual scales during
optimization while validation still accepts 1 m and 1 mm/s. Resolved solver
values are reported in `result.constraint_tolerances`; supplied settings remain
in `result.inputs.options`. Unknown fields and invalid types are errors.

## Residual scaling and stopping

Shooting and departure equations remain equalities to zero. Residuals and
Jacobian rows are scaled by the effective solver constraint tolerances. Vector
components use tolerance/sqrt(3), conservatively bounding the full vector norm.
No altitude safety margin is added to the mission constraints.

A scaled residual of `1e-9` represents one effective constraint tolerance.
`solver.constraint_tolerance` is the separate dimensionless stopping threshold
on these residuals. Its default `1e-12` targets 0.001 of each effective tolerance.
Native solver settings can alter stopping behavior; acceptance always uses
`options.validation`, regardless of convergence or solver constraint tolerances.

The Earth boundary measures outgoing excess-velocity-vector error. Trial-state
evaluation stays real outside the hyperbolic domain, while an energy guard
keeps accepted roots where that vector is exact. Independent validation
recomputes the asymptote from the physical state.

`validation.local_is_feasible` reports local checks. Overall `is_feasible`
requires local and chained checks. Tighter local solver tolerances can leave
margin for accumulated error but cannot guarantee chained closure.

`options.integration` controls propagation in normalized-state units and needs
sufficient precision for the requested tolerances. `solver.optimality_tolerance`
concerns objective stationarity. Neither is silently changed by validation or
constraint tolerance settings.
