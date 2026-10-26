# MATLAB contracts, schema 1

Only the library root belongs on MATLAB's path. The namespace is `orb2ds`.
Public scientific quantities use km, km/s, days and radians. Reference states
are six-component columns; node histories have one state per row. Orbital and
shooting states are barycentric rotating `[x,y,z,vx,vy,vz]`.

ECI means the idealized Earth-centered inertial axes associated with the model:
+Z is the CR3BP plane normal, and the lunar azimuth at local zero is
`moon_angle_ref_rad`. This does not silently assign a J2000 date or an
ephemeris orientation. A target in an external inertial convention must be
expressed in these axes explicitly.

## Case preparation

A configuration `.m` function returns one plain `cfg` structure.

`examples/config_example.m` is the complete annotated template. Copy it to any
directory; rename its function when renaming the file. No `cases` directory is
required. Every supported numerical leaf is explicit there; remove a leaf to
inherit the library default. Exclusive orbit/target alternatives are commented.

Allowed blocks:

| Field | Meaning |
|---|---|
| `orbit` | Complete inline orbit descriptor; mutually exclusive with `files.orbit`. |
| `files.orbit` | Relative/absolute MAT path containing variable `orbit`. |
| `files.database` | Optional MAT path containing canonical variable `database`. |
| `target` | Prescribed outgoing Earth-relative excess velocity. |
| `constraints` | Optional physical restrictions below. |
| `options` | Numerical settings; omitted fields inherit library defaults. |

`[problem, options] = orb2ds.load_case(filename)` resolves file references
relative to that configuration, loads declared data, checks descriptors and
completes numerical defaults. It restores the original working directory and
does not modify the caller's workspace. Configuration code must describe the
case without starting propagation, database generation or optimization.

The same prepared structures may be constructed directly. `find_transfer`
requires a loaded database; `optimize_transfer` does not read one. Numerical
defaults and validation are shared by preparation and direct stage calls.
Unknown fields are errors. Omit numerical fields for their defaults; empty
numerical leaves are rejected. Empty physical constraints mean absent/free.

`options.output.display` controls automatic library search/stage/physical-summary
messages. `options.solver.display` independently passes `'off'`, `'final'`,
`'iter'` or `'iter-detailed'` to fmincon. Generic defaults are `true` and `'off'`;
the example case explicitly enables `'iter'`. These settings affect presentation
only. Stage 1 has zero objective; stage 2 displays normalized total delta-v,
converted to m/s by `model.velocity_km_s*1000`. Native normalized feasibility
and solver stopping measures are distinct from independent physical validation.

## Orbit and model

An orbit has `schema_version=1`, `state_ref` (6x1 physical rotating state),
`period_days` and `model`. `orb2ds.earth_moon_model(parameters)` derives `mu`,
`time_days`, `velocity_km_s` and `encounter_radius_km` from primary GMs, separation
and radii. Derived scales cannot be independently changed. The orbit's period
and reference phase are not inferred from a database or automatically corrected.

Primary model parameters are `gm_earth_km3_s2`, `gm_moon_km3_s2`, `distance_km`,
`earth_radius_km`, `moon_radius_km`, and `moon_angle_ref_rad`. The default mass
ratio equals the source orbit's 0.0121506683. One circular angular rate follows
from the total GM and separation. The SOI-entry boundary follows the recovered
producer convention: lunar radius plus the Laplace SOI radius.

Local `t=0` identifies the supplied seed's reference event. Normalized phase
`s=0` identifies `state_ref`; phase evolves through flow over `s*period_days`.
Phase 1 is accepted as phase 0. Declaring those coordinates never supplies
`initial_time_days=0` or `initial_phase=0` as implicit constraints.

MJD2000 input and automatic astronomical Earth-Sun/Earth-Moon geometry are a
future extension. Exact or windowed final epochs are also future work and are
rejected explicitly in this implementation.

## Target and physical constraints

`target.vinf_km_s` is a nonzero 3x1 vector. `target.frame` is `eci` or
`earth_sun_rth`. RTH additionally requires `solar_geometry.angle_ref_rad` and
`solar_geometry.rate_rad_day`. The angle is Earth-to-Sun at local t=0; R points
Sun-to-Earth, T follows the declared planar heliocentric motion and H is +Z.
The requested vector is constant in its declared frame. The NLP converts RTH
at the actual final epoch, including its time derivative. Patching uses an
epoch-zero target snapshot for initialization; the final target is never frozen
to that snapshot. Ephemeris generation and solar gravity are not added.

| Constraint | When present |
|---|---|
| `initial_time_days` | Epoch of the initial vehicle event, before waiting. |
| `initial_phase` | Normalized orbital phase at that event. |
| `max_wait_time_days` | Waiting upper bound; zero forbids waiting. |
| `max_transfer_time_days` | Upper bound from departure to final Earth perigee. |
| `max_total_time_days` | Upper bound including applicable waiting. |
| `min_earth_altitude_km` | Earth clearance above the model radius. |
| `min_moon_altitude_km` | Lunar clearance above the model radius. |
| `impulse_nodes` | `all` (default) or `endpoints`. |
| `final_time_days` | Planned scalar/window input; currently rejected as unsupported. |

Omitted quantities stay free. Body impacts are always excluded. Caps intersect;
none silently overrides another. If neither initial epoch nor phase is supplied,
departure epoch and phase are independent optimization quantities, no earlier
event is invented, waiting caps are redundant and total equals transfer time.
Otherwise waiting is nonnegative. A known epoch sets `td=t0+w`; a known phase
sets `sd=mod(s0+w/T,1)`. Missing epoch/phase remains free. Compatible redundant
caps are accepted and obvious redundancies are reported.

## Database and stage outputs

`build_orbit_moon_database(orbit, filename, options)` explicitly generates/saves
or reuses a matching completed archive. It never overwrites an existing file.
Reusing a filename requires matching orbit, grid and integration settings.
`load_orbit_moon_database` reads the versioned variable `database`; it does not
guess metadata or convert a historical table implicitly.

A database has `schema_version`, `orbit`, `encounters`, `definition`,
`generation`, `provenance`. Encounter arrays are:

| Field | Shape/meaning |
|---|---|
| `row_id` | Nx1 ordered identifiers, starting at 1. |
| `departure_phase` | Nx1 normalized reference phase. |
| `delta_v_km_s` | Nx3 rotating departure impulses. |
| `duration_days` | Nx1 positive time from departure to entry. |
| `state_entry` | Nx6 physical rotating state at the lunar boundary. |
| `velocity_local_rth_km_s` | Nx3 local Moon-relative inertial velocity in Moon-RTH axes. |
| `velocity_infinity_rth_km_s` | Nx3 inbound two-body asymptote; NaN for nonhyperbolic encounters. |

The generator retains every inward entry and stops an integration at Earth or
Moon impact. Its finite horizon and grid are numerical search bounds. Stored
states and both velocity definitions are checked for consistency on load.

`find_legs` returns a compact ranked candidate array, copying the orbit-side
departure data, Earth-side Lambert state/perigee/impulse, lunar asymptotes and
source/ranking metadata. Assembly does not subsequently look up database rows.
The matcher preserves altitude growth/improvement, speed neighbors, deflection
screening, Earth-burn ranking and closest-speed neighbor selection.

`assemble_transfer` returns compact CR3BP/Earth-two-body propagation recipes,
SOI entry/perilune/exit and Earth-perigee epochs, impulses and provenance.
An unreconstructible finite lunar passage returns empty. `mesh_transfer` samples
those recipes, retains event anchors and emits the node record below. Patch
defects remain visible. Optimization never silently rediscretizes that record.

## Compact physical node record

Guesses, solutions and failed candidates share:

- `schema_version=1`, complete `orbit` and its model/frame/time conventions;
- `nodes.time_days`: Nx1 strictly increasing epochs;
- `nodes.state_post`: Nx6 post-impulse rotating physical states;
- `nodes.delta_v_km_s`: Nx3 impulses in the same axes;
- `events`: physical event epochs and node associations, including
  `moon_periapsis_node` for the optimizer;
- `timing`: departure phase, applicable waiting, transfer and total durations;
- `integration` and construction `provenance`; optional compact `metrics`.

At a node, pre-burn velocity is `state_post(4:6)-delta_v`. Each segment therefore
arrives before the receiving node's impulse. Discontinuities are retained, and
reconstruction never overwrites nodes to hide a defect. A guess need not satisfy
the current target, all physical limits, or shooting continuity. Orbit/model/
conventions and structural validity must match the current problem.

`solver.minimum_segment_days` is the explicit numerical resolution preventing
collapsed shooting epochs (default 1e-6 days). It is not a mission-duration
cap. A requested cap incompatible with the selected node count/resolution is
a numerical-configuration error. Reduce the resolution or choose a coarser mesh.

The runtime NLP holds normalized states, Oshima variables, independent timing
quantities, bounds and callbacks. It is not persisted. Both solver stages use
the same constraints, with zero objective first and total delta-v second.

## Result and reconstruction

`result` contains status, `solution`, `candidate`, `validation`, `seed`, compact
`solver` diagnostics, attempt summaries, active constraints, effective inputs
(without the database), and provenance. `find_transfer` also reports search
diagnostics. Distinguish `no_seed_found`, `no_validated_solution`,
`feasible_converged` and `feasible_without_optimization_convergence`.

`solution` is the lowest-cost validated record among checked stage candidates
and starts. When no record is accepted, `candidate` retains the failed checked
record if one exists. Solver exit flags and independent physical acceptance
are separate. Best-feasible points reported by fmincon are checked as well;
no optimizer vectors or callbacks are copied into result diagnostics.

`reconstruct_trajectory(solution, settings)` returns a separate transient
trajectory, segment by segment, including endpoint defects and distinct
pre/post states. `plot_trajectory(trajectory, settings)` plots it without saving.
Its default `frame='rotating'` displays barycentric DU; `frame='eci'` transforms
each sample at its epoch to Earth-centered km. Default `view=[0,90]` shows XY
without dropping Z. `show_nodes=true`, `show_impulses=true` and
`impulse_scale=0.38` reproduce the thesis overlays. Arrows are uniformly scaled
to the trajectory extent; their relative strengths and three-dimensional
directions are preserved. They are not physical position increments. See the
examples guide for all plot controls and command-window settings.
No function saves transfer results automatically. Saving `result.solution`
alone retains everything needed to reconstruct it without the database.

Sampled trajectories never appear inside results, including seeds, failed
candidates and multistart attempts. Optional `output.keep_attempt_solutions`
retains compact records only. Independent chained propagation is reported
separately from multiple-shooting feasibility; see VALIDATION.md.
