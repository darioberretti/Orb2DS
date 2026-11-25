# Integration, initial mesh and guess inspection

Propagation accuracy and shooting-node spacing have separate controls.

## Integration accuracy

`options.integration.relative_tolerance` and `absolute_tolerance` are positive,
finite scalars passed to MATLAB's `ode113`. They apply to normalized dynamics:
positions are divided by `model.distance_km`, velocities by
`model.velocity_km_s`, and time by `model.time_days`. The absolute tolerance
therefore has normalized-state units, not km or km/s. Generic defaults are
1e-13 relative and 1e-14 absolute.

The symbolic IPOPT route uses the same settings for CVODES unless its native
settings are overridden through `options.solver.cvodes`. Independent physical
validation uses `ode113`. Integration tolerances do not set node counts or
physical acceptance thresholds; see [VALIDATION.md](VALIDATION.md).

## Initial shooting mesh

The initial mesh has one global maximum time spacing and one optional refinement
interval. The builder derives the node count from arc durations, spacing and
event anchors. Specify time spacing in local days, for example:

```matlab
cfg.options.mesh.max_step_days = 0.5;
cfg.options.mesh.refinement = struct( ...
    'from', 'moon_periapsis', ...
    'from_offset_days', -1, ...
    'to', 'earth_periapsis', ...
    'factor', 10);
```

This example uses a maximum initial step of 0.5 days outside the interval and
0.05 days from one day before lunar periapsis through Earth periapsis. It keeps
the entire critical late transfer dense, including the post-lunar portion.
These numbers illustrate the interface; they are not a convergence guarantee.

## Settings and boundaries

| Field | Meaning |
|---|---|
| `max_step_days` | Global maximum initial segment duration; default 0.5 days |
| `refinement.from` | Start event; choose any name in the event table below |
| `refinement.from_offset_days` | Signed offset from the start event in days; negative is earlier, zero is at the event, positive is later |
| `refinement.to` | End event; choose any name in the event table below; no end offset is applied |
| `refinement.factor` | Finite value >=1; divide the maximum step by this factor inside the interval; 1 disables refinement |

Both `from` and `to` accept the following names. They refer to events in the
assembled transfer, not numeric node indices.

| Event name | Physical anchor |
|---|---|
| `'departure'` | Departure from the supplied periodic orbit |
| `'moon_entry'` | Inward crossing of the model's lunar encounter boundary |
| `'moon_periapsis'` | Lunar closest-approach anchor of the assembled guess |
| `'moon_exit'` | Outward crossing of the same lunar boundary |
| `'earth_periapsis'` | Final Earth-perigee arrival |

The lunar boundary radius is `model.encounter_radius_km`, measured from the Moon.
The interval starts at `time(from) + from_offset_days` and ends at `time(to)`.
For example, start at `'moon_entry'` with offset 0 and end at `'moon_exit'`
to refine the lunar passage alone. Offset -1 starts one day before the selected
event; +1 starts one day after it. Arbitrary node-index anchors are not supported.

Factor 1 uses the global maximum step on every arc; it is the generic default.
A disabled interval's event/offset values are retained but not resolved into times.

An active interval must lie entirely inside the assembled transfer and have
positive duration. `mesh_transfer` reports an error for an invalid interval.
`build_initial_guess` and `find_transfer` try the next guess with the same
offset and report that error if no assembled guess fits. Refinement uses one
manually specified interval.

The builder splits arcs at refinement boundaries and physical event times,
then samples each subinterval with the applicable spacing. It does not overlay
two independent grids. Departure, lunar entry/periapsis/exit, Earth periapsis
and the refinement boundaries are retained as exact nodes. Actual spacing may
be smaller than the requested maximum because every endpoint must be retained.
Steps or adjacent anchors below `solver.minimum_segment_days` are rejected.

```matlab
[seed, summary] = orb2ds.mesh_transfer(problem, transfer, options);
disp(summary);
disp(struct2table(summary.arcs));
```

The compact summary includes total node count, minimum/maximum initial spacing,
resolved refinement times and per-leg counts. Shared endpoints are counted in
both adjacent leg summaries. The same metadata is stored in
`seed.provenance.mesh`, with no sampled trajectories. `output.display` enables
a compact command-window report. Metadata describes initial construction;
it does not turn the refinement window into a physical mission constraint.

`optimize_transfer` preserves the supplied node count and order. Segment
durations can change, so initial spacing bounds do not constrain optimized
durations. Reusing a guess never silently rebuilds its mesh.

## Three distinct views

1. **Assembled initial guess:** `plot_initial_guess` samples each
   original recipe. The orbit-Moon leg and flyby use CR3BP; the Moon-Earth
   recipe uses Earth two-body propagation. Colors distinguish the legs.
   Automatic previews and examples show no shooting nodes in this view.
2. **NLP-transcribed initial guess:** `transcribe_guess` decodes the same
   initial vector used by `optimize_transfer`, after impulse regularization,
   timing interpretation and variable bounds/fixes. `reconstruct_trajectory`
   propagates each shooting segment in CR3BP from its post-burn node.
   `show_defects=true` draws dashed position gaps to the next stored node.
3. **Final optimization output:** examples reconstruct the accepted solution,
   or the returned candidate when validation fails. The figure title and name
   explicitly distinguish a validated transfer from an unvalidated candidate.
   Local and chained validation remain independent of visualization.

```matlab
orb2ds.plot_initial_guess(transfer);
guess = orb2ds.transcribe_guess(problem, seed, options);
trajectory = orb2ds.reconstruct_trajectory(guess);
orb2ds.plot_trajectory(trajectory, struct('show_defects', true));
```

Call `plot_initial_guess(transfer)` before meshing for physical legs alone.
An explicit `plot_initial_guess(transfer, seed, settings)` call remains
available for an optional diagnostic mesh overlay and refinement-start marker.
Its optional settings are those of `plot_trajectory` plus `samples_per_arc`
(default 200). Reconstruction's `samples_per_segment` is also a plotting-data
resolution control, independent of shooting-node spacing. Both frames are
supported: rotating coordinates in DU and ECI coordinates in km.
Position-gap lines do not visualize velocity defects; those remain available
in the transient reconstruction's six-component `defects` array.

The transcribed vector is the library's `x0` passed to the selected solver.
Solver-internal initialization, such as IPOPT's bound push, occurs afterward.
Neither initial-guess view claims physical feasibility.

## Automatic previews in examples

```matlab
cfg.options.output.plot_initial_guess = true;
cfg.options.output.plot_nlp_guess = true;
```

Both flags default to false in the library; `config_transfer.m` enables both.
They are independent of library/solver verbosity. `find_transfer` displays
both views for every attempted start. `build_initial_guess` honors the
assembled-view flag; `optimize_transfer` honors the NLP-view flag. The atomic
`mesh_transfer` and `transcribe_guess` calls do not create figures themselves.
Plot visibility inherits MATLAB's `DefaultFigureVisible` unless explicitly
supplied. Hidden previews do not force a visible-window redraw.

`step_by_step.m` makes the calls explicitly to allow custom plot settings and
disables the duplicate automatic NLP preview for its optimization call.
Plots and samples are transient: no figure handles, histories or NLP objects
are added to results, and no file is saved automatically.
