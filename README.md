# Orb2DS — Orbit-to-Deep-Space Transfer Library

Spatial Earth-Moon circular restricted three-body transfers from a supplied
periodic orbit, through a lunar encounter, to a prescribed outgoing Earth
excess-velocity vector at Earth perigee.

The repository root is the MATLAB library root. Add that folder itself to MATLAB's
path; no recursive path setup or original thesis workspace is required.
The MATLAB namespace is `orb2ds`.

```matlab
addpath('C:\path\to\Orb2DS');
[problem, options] = orb2ds.load_case( ...
    'C:\path\to\Orb2DS\examples\config_example.m');
result = orb2ds.find_transfer(problem, options);
```

MATLAB R2025b and Optimization Toolbox are the verified environment. Database
generation, reconstruction and plotting use base MATLAB. Lambert is bundled
with its source, provenance and BSD license; CasADi/IPOPT, Orbital Mechanics,
Mapping Toolbox and Statistics Toolbox are not runtime dependencies.

## Scientific stages

```matlab
candidates = orb2ds.find_legs(problem, options);
transfer = orb2ds.assemble_transfer(problem, candidates(1), options);
seed = orb2ds.mesh_transfer(problem, transfer, options);
result = orb2ds.optimize_transfer(problem, seed, options);
```

Select a returned, reconstructible candidate before meshing. An empty search
or assembly result is a reported failure to construct a seed, not a proof of
global infeasibility. `build_initial_guess` composes the first three stages.
The high-level and atomic APIs share their implementations.

`optimize_transfer` also accepts a compatible previous compact solution as its
initialization. Change the current target or constraints in `problem`; earlier
acceptance labels and targets do not carry over. The optimizer never reads the
database or silently changes the supplied mesh.

## Cases and numerical settings

Copy [config_example.m](examples/config_example.m) anywhere to prepare your own
scripts. Every input and numerical option is written out and explained, with
units, omission behavior and commented mutually exclusive alternatives.
It declares the orbit or orbit file, target, shared database and constraints.
The example database is resolved from the installed library, so the unchanged
copy also works outside this folder. Your relative data paths are resolved
against your configuration file. See [examples](examples/README.md) and
[the schema-1 contracts](docs/CONTRACTS.md).

Omitted physical restrictions stay free. In particular, the seed's phase/time
origin does not fix initial phase or epoch. All supplied caps intersect.
Numerical omissions use `orb2ds.defaults.numerical_options`; unknown settings
are rejected. Effective inputs and numerical settings are returned without
embedding the database.

The default solver uses an initial zero-objective feasibility stage followed
by delta-v minimization with the same constraints. `options.n_starts` requests
deterministic multistart over ranked candidates; set `patching.n_candidates`
large enough. Per-attempt summaries are retained, with full compact attempt
records controlled by `output.keep_attempt_solutions`.

Control library messages with `options.output.display`, and native solver
iterations independently with `options.solver.display='iter'`. The example
case enables iteration display. Stage headers distinguish zero-objective
feasibility from normalized delta-v minimization; final summaries use physical
units. The [examples guide](examples/README.md) explains candidate selection,
each `step_by_step` section and display settings.

## Database generation and reuse

The example includes a small canonical catalogue generated under one coherent
model: 720 impulsive departures and 1,986 lunar entries, approximately 164 kB.
It is a reduced demonstration input, not the historical full thesis database.
For another orbit or sampling grid, explicitly build an archive once:

```matlab
database = orb2ds.build_orbit_moon_database(orbit, 'my_catalogue.mat', options);
problem.database = database;
```

The builder reuses an existing filename only when model/orbit, generation
grid and integration settings match; it never overwrites or silently rebuilds
an existing file. The packaged catalogue records its original generation
tolerances separately from the current solver defaults. Large catalogues
remain external shared inputs or release assets.

## Compact solutions and validation

Read `result.status`, `result.validation.checks` and the solver's own stopping
information separately. `solution` contains the lowest-cost validated record
found; if none passes, `candidate` can retain the failed checked record.
Neither result implies a global optimum or proof of infeasibility.

Validation independently propagates every segment, checks interior radial
extrema/body clearance, orbit departure, timing and achieved escape velocity.
It also chains every burn without resetting to the stored nodes. That stricter
diagnostic has its own `validation.chained.is_feasible` flag: local shooting
defects and accumulated chained error are different quantities.

```matlab
trajectory = orb2ds.reconstruct_trajectory(result.solution);
orb2ds.plot_trajectory(trajectory);
```

Plots follow the thesis style: black arcs and node circles, blue scaled burns,
Times labels and a rotating XY view in DU. Use `struct('frame','eci')` for the
inertial view in km, or `struct('view',[-37.5,30])` to inspect the full 3D curve.

Reconstruction requires only the compact solution. It preserves velocity jumps
and reports segment defects. No function saves transfer results or figures
implicitly, and sampled trajectories never appear anywhere inside `result`.
Save `result.solution` explicitly when that is all you need.

## Verification and scope

Run the regression suite from the library root:

```matlab
results = runtests(fullfile(pwd, 'tests'));
assertSuccess(results);
```

[Validation evidence](docs/VALIDATION.md) distinguishes the new canonical case,
unchanged historical controls, numerical checks and future work.
[Provenance](docs/PROVENANCE.md) identifies reused source and deliberate changes.

The initial model is spatial Earth-Moon CR3BP with periodic input orbits.
Integrated reference validation uses the supplied RPO; it does not establish
coverage of every periodic family or transfer feasibility for every orbit.
Exact/windowed final-epoch algorithms, MJD2000/ephemeris preparation, additional
objectives/backends and the native Python port remain future work.

This is an initial research version, validated on the documented cases.

## License and citation

The project code, documentation and bundled example/test data are available under
the [MIT License](LICENSE), except where separate third-party notices apply.
The bundled FEX-Lambert component
by Rody Oldenhuis retains its original
[BSD-2-Clause license](+orb2ds/+thirdparty/+fexlambert/License.txt). Its source and
license notice are preserved unchanged; the project license does not replace them.

If you use Orb2DS in research, please cite the software using
[CITATION.cff](CITATION.cff) or GitHub's **Cite this repository** option.
