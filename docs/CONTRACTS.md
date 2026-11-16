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

`examples/config_transfer.m` is the complete annotated transfer template. Copy it to any
directory; rename its function when renaming the file. Every supported
numerical leaf used for transfers is explicit there; remove a leaf to
inherit the library default. Exclusive orbit/target alternatives are commented.

Database generation uses the separate `examples/config_database.m`. That
example returns `cfg.orbit`, `cfg.output.database`, `cfg.output.orbit` and the
numerical settings consumed by the builder. Its script passes the orbit and
options directly to `build_orbit_moon_database`, then exports the orbit MAT.
The generation configuration is not an input to `load_case` and requires no
transfer target. `examples/workspace/` demonstrates both configurations in a
standalone project, sharing the orbit through the exported file.

Allowed blocks:

| Field | Meaning |
|---|---|
| `orbit` | Complete inline orbit descriptor; mutually exclusive with `files.orbit`. |
| `files.orbit` | Relative/absolute MAT path containing variable `orbit`. |
| `files.database` | Optional MAT path containing canonical variable `database`. |
| `target` | Prescribed outgoing Earth-relative excess velocity. |
| `constraints` | Optional physical restrictions below. |
| `options` | Numerical settings; omitted fields inherit library defaults. |
| `output` | Optional saving directory, MAT filename and overwrite authorization; separate from numerical options. |

`[problem, options] = orb2ds.load_case(filename)` resolves file references
relative to that configuration, loads declared data, checks descriptors and
completes numerical defaults. It restores the original working directory and
does not modify the caller's workspace. Configuration code must describe the
case without starting propagation, database generation or optimization.

An optional third return value resolves `cfg.output.directory` against the
configuration file, with defaults `Orb2DS_output`, filename `transfer_result.mat`
and `overwrite_without_prompt=false`. Loading does not create folders, authorize
overwriting or save anything. Calling scripts use `prepare_output` before the
calculation and `save_output` afterward; see [saving behavior](OUTPUT.md).

The same prepared structures may be constructed directly. `find_transfer`
requires a loaded database; `optimize_transfer` does not read one. Numerical
defaults and validation are shared by preparation and direct stage calls.
Unknown library fields are errors; explicit native solver/integrator blocks
admit options validated by their respective libraries. Omit numerical fields for their defaults; empty
numerical leaves are rejected except optional solver constraint tolerances,
where [] inherits the corresponding validation tolerance. Empty physical
constraints mean absent/free, except `max_wait_time_days`: omitted or []
resolves to zero and disables waiting, including in direct stage calls.

`options.output.display` controls automatic library search/stage/physical-summary
messages. `options.solver.display` independently selects `'off'`, `'final'`,
`'iter'` or `'iter-detailed'` for the selected solver. Generic defaults are `true` and `'off'`;
the example case explicitly enables `'iter'`. These settings affect presentation
only. Stage 1 has zero objective; stage 2 displays normalized total delta-v,
converted to m/s by `model.velocity_km_s*1000`. Native normalized feasibility
and solver stopping measures are distinct from independent physical validation.

Console blocks have phase headings and aligned diagnostics. `node_table(result)`
returns every node's epoch and rotating impulse components/magnitude in m/s;
it chooses solution, then candidate. `print_result(result)` explicitly prints
stored physical diagnostics without propagation. Neither modifies the result
or writes files. See [logging and data inspection](LOGGING.md).

## Orbit and model

An orbit has `schema_version=1`, `state_ref` (6x1 physical rotating state),
`period_days` and `model`. `orb2ds.earth_moon_model(parameters)` derives `mu`,
`time_days`, `velocity_km_s` and `encounter_radius_km` from primary GMs, separation
and radii. Derived scales cannot be independently changed. The orbit's period
and reference phase are not inferred from a database or automatically corrected.

Primary model parameters are `gm_earth_km3_s2`, `gm_moon_km3_s2`, `distance_km`,
`earth_radius_km`, `moon_radius_km`, and `moon_angle_ref_rad`. The default mass
ratio is 0.0121506683. One circular angular rate follows from the total GM and
separation. The encounter boundary radius is the lunar radius plus the Laplace
sphere-of-influence radius, measured from the Moon.

Local `t=0` identifies the supplied seed's reference event. Normalized phase
`s=0` identifies `state_ref`; phase evolves through flow over `s*period_days`.
Phase 1 is accepted as phase 0. Declaring those coordinates never supplies
`initial_time_days=0` or `initial_phase=0` as implicit constraints.

Epochs use local days. MJD2000 input, automatic astronomical Earth-Sun/Earth-Moon
geometry and nonempty final-epoch requests are unsupported.

## Target and physical constraints

`target.vinf_km_s` is a nonzero 3x1 vector. `target.frame` is `eci` or
`earth_sun_rth`. RTH additionally requires `solar_geometry.angle_ref_rad` and
`solar_geometry.rate_rad_day`. The angle is Earth-to-Sun at local t=0; R points
Sun-to-Earth, T follows the declared planar heliocentric motion and H is +Z.
The requested vector is constant in its declared frame. The NLP converts RTH
at the actual final epoch, including its time derivative. Patching updates the
RTH target at estimated arrival epochs and assembly refines it using the
reconstructed timing. Ephemeris generation and solar gravity are not added.

| Constraint | Meaning |
|---|---|
| `initial_time_days` | Epoch of the initial vehicle event, before waiting. |
| `initial_phase` | Normalized orbital phase at that event. |
| `max_wait_time_days` | Waiting cap [days]. Omitted, [] or 0 disables waiting; a positive finite scalar enables it. Other values are input errors. |
| `max_transfer_time_days` | Upper bound from departure to final Earth perigee. |
| `max_total_time_days` | Upper bound including applicable waiting. |
| `min_earth_altitude_km` | Earth clearance above the model radius. |
| `min_moon_altitude_km` | Lunar clearance above the model radius. |
| `impulse_nodes` | `all` (default) or `endpoints`. |
| `final_time_days` | Must be empty or omitted; nonempty values are unsupported. |

Omitted quantities stay free except waiting, which defaults to zero. Body
impacts are always excluded. Caps intersect; none silently overrides another.
If neither initial epoch nor phase is supplied,
departure epoch and phase are independent optimization quantities, no earlier
event is invented, waiting caps are redundant and total equals transfer time.
Otherwise waiting satisfies `0 <= w <= max_wait_time_days`, with zero used
when that cap is omitted or []. A known epoch sets `td=t0+w`; a known phase
sets `sd=mod(s0+w/T,1)`. Missing epoch/phase remains free. Compatible redundant
caps are accepted and obvious redundancies are reported.

## Database and stage outputs

`build_orbit_moon_database(orbit, filename, options)` explicitly generates/saves
or reuses a matching completed archive. It never overwrites an existing file.
Reusing a filename requires matching orbit, grid and integration settings.
`load_orbit_moon_database` reads the versioned variable `database`; it does not
infer missing metadata or convert incompatible data.

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
The default `patching.method = 'ballistic'` uses altitude growth, speed
neighbors and deflection screening. Select `'powered'` to evaluate a shared
perilune for two lunar hyperbolas. The powered search uses the incoming
osculating asymptote at SOI entry and estimates the outgoing asymptote from
the center-based Earth leg. It resolves both vectors in common inertial axes
and samples perilune radii between the minimum lunar altitude and the
encounter radius. At each Earth altitude, the matcher sorts the departure
replicas by their minimum-radius perilune speeds and evaluates neighbors
of each Earth leg first. A single shortlist at each Earth altitude shares
its cutoff across all lunar encounter bins. Binary searches restrict the
speed interval when this cutoff bounds the weighted cost. Pair-level bounds
also account for timing, phase, departure and Earth impulses. The powered
search accepts different incoming and outgoing speeds. It requires
`impulse_nodes = 'all'` (or the omitted default).

The powered shortlist prioritizes time-cap compliance and exact database
departure phases. It then sums the departure and Earth impulse magnitudes,
the lunar impulse magnitude multiplied by `patching.lunar_impulse_weight`,
and `patching.time_weight_m_s_day` times flight duration. The lunar weight
is dimensionless and at least 1, with a default of 1. The nonnegative
flight-time weight defaults to zero and uses m/s per day.
Waiting contributes to time-cap checks. Lunar epoch mismatch and flight
duration break score ties. Multiple rows can match the same Earth leg.
Identical departure replicas share one shortlist entry per Earth leg.
`find_legs` returns up to `patching.n_candidates` provisional matches.
For powered searches, `find_transfer` assembles that pool and optimizes up
to `n_starts` usable guesses in ascending assembled impulse sum with the
same lunar multiplier. The reported physical delta-v and solver objective
use the actual impulses. `build_initial_guess` uses the same ranking to select one
guess. The reported candidate index identifies the original `find_legs`
match. The SOI entry gap is reported as a diagnostic.

When the initial epoch is specified, both matchers compute each orbit leg's
lunar SOI entry epoch from the initial epoch, wait and catalogue duration.
For an ECI target, assign that encounter to the nearest sampled Moon angle
on the circle. For an Earth–Sun RTH target, assign it to the nearest absolute
epoch on the bounded Earth-leg grid. Search for velocity matches only within
the assigned batches. A free spacecraft phase with positive wait can reach
several batches. With a prescribed spacecraft phase, each waiting replica
determines one batch.

Initial-event constraints also specialize the construction:

| Supplied initial information | Guess construction |
|---|---|
| Neither epoch nor phase | Search all database departure phases; let lunar geometry determine epoch. Waiting is zero. |
| Phase, waiting forbidden | Search the two closest circular database phase slices and seed departure at the selected catalogue phase. Epoch stays free. |
| Phase, waiting allowed | Also search database phases reachable by forward waiting. Epoch stays free. |
| Epoch, waiting forbidden | Assign every catalogue departure to the batch at its anchored lunar encounter. Phase stays free. |
| Epoch, waiting allowed | Include batches reachable during the allowed wait. Phase stays free. |
| Both, waiting forbidden | Combine the phase shortlist with the anchored encounter-epoch search. |
| Both, waiting allowed | Also search subsequent orbit revolutions; phase and epoch advance by the same wait. |

Ballistic ranking first minimizes estimated time-cap excess, prefers exact database
departure phases over borrowed neighboring-phase data, then minimizes lunar
epoch mismatch and estimated Earth burn. Within one Earth leg, closest lunar
speed breaks ties. With no initial constraints and inactive duration caps,
this reduces to Earth-burn ranking. A shortlist uses approximate two-body inbound
flyby durations; assembly recomputes timing with the finite CR3BP passage.

`patching.n_moon` samples lunar angles, or absolute encounter epochs for an
RTH target with a specified departure epoch (default 201). With both initial quantities specified,
the matcher enumerates waits `w0 + k*T <= max_wait_time_days`, where `w0` is
the first forward wait to the database phase and `T` is the orbit period.
With only epoch supplied, the encounter window spans the permitted wait.
With only phase supplied, the earliest wait to each database phase suffices
because departure epoch remains free. Transfer and total caps are then
screened together with waiting; they remain unchanged in the NLP.
`patching.target_iterations` is a positive integer, default 8, bounding RTH
arrival-epoch updates and finite-patch refinements.

The returned search diagnostics include the shortlisted database phase grid,
row/replica counts and best timing estimate. A finite search is not a proof
that no compatible patch exists. If every sampled patch exceeds a time cap,
the lowest-excess guesses are retained without changing the requested cap.

`assemble_transfer` returns compact CR3BP/Earth-two-body propagation recipes,
SOI entry/perilune/exit and Earth-perigee epochs, impulses and provenance.
Departure is propagated at the selected catalogue phase so the departure
state, burn and encounter duration describe the same arc. The NLP enforces
the requested initial phase through its departure-state constraints. The
guess epoch is anchored to `initial_time_days + wait_days` when specified.
The wait is carried through meshing into the NLP. Exact timing-cap excess, lunar epoch mismatch and
`meets_time_caps` are recorded under `provenance.seed_screening`; RTH also
reports `target_epoch_error_km_s`. These describe guess construction, not
physical acceptance. The optimizer adjusts the initial node to the required
departure phase and corrects the remaining patch defects.

With a fixed departure epoch, ballistic assembly starts a new tangent Earth
leg from the finite lunar SOI exit at its anchored epoch. The fit updates
flight time and terminal impulse. The lunar flyby uses a single continuous
arc and the exit velocity defect remains part of the shooting guess.

Powered assembly places pre- and post-burn lunar arcs at one perilune with a
single rotating-frame impulse. It propagates to the finite SOI crossings,
rebuilds the tangent Earth leg from the exit position and epoch, and
iterates on the outgoing osculating asymptote and flight timing. A
reconstructible iterate can retain a residual. The `powered_patch`
provenance contains the refined total impulse, remaining asymptote and
entry timing discrepancies, and the SOI position and velocity gaps in
entry/exit order [km, km/s]. These gaps are diagnostic.
An unreconstructible finite lunar passage returns empty. `mesh_transfer` samples
those recipes, retains event anchors and emits the node record below. Patch
defects remain visible. Optimization never silently rediscretizes that record.
`mesh.max_step_days` bounds initial spacing. Optional `mesh.refinement`
selects an event interval using `from`, `from_offset_days`, `to` and `factor`;
factor 1 disables refinement. Exact physical anchors and interval boundaries
are retained. `mesh_transfer` also returns a compact summary stored in
`seed.provenance.mesh`. See [MESH.md](MESH.md) for interval validation and plots.

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
Mesh spacing limits apply to the initial guess, not optimized segment durations.

The runtime NLP holds normalized states, Oshima variables, independent timing
quantities, bounds and callbacks. It is not persisted. Both solver stages use
the same constraints, with zero objective first and total delta-v second.
`solver.name` selects fmincon or IPOPT; `solver.evaluation` selects MATLAB
functions or a CasADi/CVODES graph (IPOPT only). See [SOLVERS.md](SOLVERS.md)
for native-option precedence and the explicit tolerance mappings.
`transcribe_guess(problem, seed, options)` exposes the corresponding compact
physical initialization, without solving or requiring a solver dependency.

## Result and reconstruction

`result` contains status, `solution`, `candidate`, `validation`, `constraint_tolerances`, `seed`, compact
`solver` diagnostics, attempt summaries, active constraints, effective inputs
(without the database), and provenance. `find_transfer` also reports search
diagnostics. By default stages and starts are ranked by delta-v solver
convergence and then cost. Set `options.validation.enabled=true` to check
returned points after solving. When no delta-v solve converges, this gives
physically validated points priority, followed by cost.
`options.validation.require_pass=true` also enables the checks and prioritizes
the lowest-cost validated point.

The selected record is stored in `solution` if it passes the local and chained
checks. `candidate` holds the selected record when checks are skipped or it
falls outside the physical criteria. When checks run, `validation` holds the
selected record's diagnostics and `solver.stage_validation` holds stage
diagnostics. Otherwise these diagnostics are empty. Each start summary
reports the initial guess cost, the selected point's cost and flight time,
physical acceptance and solver convergence. The initial SOI entry state gap
is the Euclidean norm of the difference between the orbit-side and flyby
states at the same entry epoch, before meshing. Position and velocity
components use the model distance and velocity units. Each start also reports the maximum
constraint violation at the end of the delta-v solve as reported by the
backend (`constrviolation` for fmincon, `inf_pr` for IPOPT, or NaN if
unavailable). The solver's final iterate can differ from the selected point.
`solver.selected_stage` identifies the returned record. `solver.converged`
reports convergence of its delta-v solve independently of the physical verdict.
Best-feasible points from fmincon carry the termination status of their solve.
With fmincon SQP, a failed shooting integration during a trial evaluation
signals undefined constraints so the line search can try a smaller step.
If a propagation error ends a start in `find_transfer`, its attempt has
status `integration_failed` and an `integration_failure` message. Shooting
errors identify the segment's node indices. The start counts toward `n_starts`
and its final metrics are NaN. The search continues with the available budget.
Solver vectors with unordered node epochs are skipped during candidate
selection. If this ends a start, its status is `invalid_solver_timeline`
and its `solver_timeline_failure` records the rejected output.
If a stage record can be retained, `solver.timeline_failures` lists any
solver outputs skipped for unordered epochs.

| `result.status` | Meaning |
|---|---|
| `feasible_converged` | The selected point passes physical checks and its delta-v solve converged. |
| `feasible_without_optimization_convergence` | The selected point passes physical checks and delta-v convergence was not reached for it. |
| `transfer_found` | A convergent solve returned a candidate without physical acceptance. |
| `candidate_available` | A stopped solve returned a candidate without physical acceptance. |
| `no_validated_solution` | Strict selection found only points outside the physical criteria. |
| `no_seed_found` | Search found no initial guess to optimize. |
| `integration_failed` | No start returned a record and the latest start ended with a propagation error. |
| `invalid_solver_timeline` | No start returned a record and the latest start ended with an invalid timeline. |
Each stage records its solver/evaluation route, effective native options,
iterations and stopping information. IPOPT's native `return_status` is retained;
`Solved_To_Acceptable_Level` is distinguished from `Solve_Succeeded` and does
not set the shared optimization-converged flag. A validated point from an
iteration-limited or acceptable-level solve can still be returned as a solution.

`reconstruct_trajectory(solution, settings)` returns a separate transient
trajectory, segment by segment, including endpoint defects and distinct
pre/post states. `plot_trajectory(trajectory, settings)` plots it without saving.
Its default `frame='rotating'` displays barycentric DU; `frame='eci'` transforms
each sample at its epoch to Earth-centered km. Default `view=[0,90]` shows XY
without dropping Z. `show_nodes=true`, `show_impulses=true` and
`impulse_scale=0.38` control the displayed nodes and arrows. Arrows are uniformly scaled
to the trajectory extent; their relative strengths and three-dimensional
directions are preserved. They are not physical position increments. See the
examples guide for all plot controls and command-window settings.
`show_defects=true` draws position gaps between propagated endpoints and
receiving nodes. `plot_initial_guess(transfer, seed, settings)` instead samples
the original physical arc recipes in distinct colors, with optional mesh
overlay and a refinement-start marker. Automatic initial previews are enabled
independently by `output.plot_initial_guess` and `output.plot_nlp_guess`;
neither stores trajectories or figure handles inside results. Automatic
assembled previews show physical legs without a mesh overlay. The basic and
step-by-step examples plot a returned failed candidate as well, labeling it
as unvalidated without moving it into `result.solution`.
No function saves transfer results automatically. Saving `result.solution`
alone retains everything needed to reconstruct it without the database.

Sampled trajectories never appear inside results, including seeds, failed
candidates and multistart attempts. Optional `output.keep_attempt_solutions`
retains compact records only. Independent chained propagation is reported
alongside `validation.local_is_feasible`. Overall `validation.is_feasible`
requires both; see [VALIDATION.md](VALIDATION.md). `result.validation.tolerances`
lists acceptance thresholds and `result.constraint_tolerances` lists resolved
solver scales. [ACCURACY.md](ACCURACY.md) defines their inheritance and residual scaling.
