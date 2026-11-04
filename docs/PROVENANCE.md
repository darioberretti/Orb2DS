# Attribution and bundled data

Orb2DS code, documentation and bundled example/test data use the
[MIT License](../LICENSE). The Lambert solver has a separate license.

## Lambert solver

The bundled FEX-Lambert v1.4 implementation is by Rody Oldenhuis. Its source is
[`lambert.m`](../+orb2ds/+thirdparty/+fexlambert/lambert.m), with the
[BSD-2-Clause license](../+orb2ds/+thirdparty/+fexlambert/License.txt) and
[component information](../+orb2ds/+thirdparty/+fexlambert/README.md) alongside it.
That license and copyright notice apply to the component.

Orb2DS calls it through `orb2ds.internal.solve_lambert`, using positions in km,
flight time in days and velocities in km/s. Transfer matching uses the
zero-revolution retrograde branch.

## Bundled numerical kernels

`+orb2ds/+internal/rhs_CR3BP_3D.m` implements spatial circular restricted
three-body dynamics; `rhs_CR3BP_3D_STM.m` adds the analytic state-transition
matrix equations. `rp_circle_from_vinfplus.m` samples Earth-perigee directions
for a prescribed outgoing asymptote. All runtime dependencies are included
in the repository or listed in the [setup guide](../README.md).

## Example catalogue

[`data/orbit_moon_example.mat`](../data/orbit_moon_example.mat) contains a
schema-1 database generated with `orb2ds.build_orbit_moon_database`. Its grid
uses 12 departure phases, impulse magnitudes 0, 10, 20, 30 and 50 m/s,
12 in-plane directions and a 50-day propagation horizon. This produces
720 sampled departures and 1,986 inward lunar encounters. Zero-magnitude
impulses repeat across direction samples. Generation integration tolerances
are relative 1e-12 and absolute 1e-12.

The database embeds its orbit, model, grid, integration settings and velocity
conventions. The example configuration supplies a compatible orbit and an
outgoing Earth excess-velocity target. Generate a matching database when
changing the orbit, model or catalogue sampling.

## Test fixture

[`tests/fixtures/validated_transfer.mat`](../tests/fixtures/validated_transfer.mat)
contains an optimized compact transfer and its problem definition. The tests
use it for reconstruction, validation, reinitialization and derivative checks.
Matching and assembly tests construct guesses using the example catalogue.

See [CONTRACTS.md](CONTRACTS.md) for data fields and physical conventions, and
[VALIDATION.md](VALIDATION.md) for the numerical checks.
