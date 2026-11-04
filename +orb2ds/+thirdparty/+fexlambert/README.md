# FEX-Lambert v1.4

This directory contains Rody Oldenhuis's
[FEX-Lambert v1.4](https://github.com/rodyo/FEX-Lambert/releases/tag/v1.4)
source and its [BSD-2-Clause license](License.txt).

Upstream commit: `f220826e6ac688ae8dfd2e8c9374872e43ea9fb4`.
The solver implementation and license notice are distributed unchanged.

Orb2DS calls `orb2ds.thirdparty.fexlambert.lambert` through
`orb2ds.internal.solve_lambert`. The wrapper supplies positions in km,
time of flight in days and gravitational parameter in km^3/s^2; it returns
velocities in km/s and checks the solver's success flag. Transfer matching
uses the zero-revolution retrograde branch.
