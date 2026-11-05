function [equality, inequality] = constraint_scales(nlp)
%CONSTRAINT_SCALES Scale each solver constraint tolerance to a residual of 1e-9.
%   Vector components use tolerance/sqrt(3) to conservatively bound their norm.
%   A solver threshold of 1e-12 targets 0.001 of these physical scales.
%   Acceleration signs use a velocity-per-model-time reference; the positive
%   escape-energy guard is dimensionless before the common scaling.

a = nlp.constraint_tolerances;
model = nlp.model;
dynamics = sqrt(3) * [repmat(model.distance_km / a.dynamics.position_km, 3, 1); ...
    repmat(model.velocity_km_s / a.dynamics.velocity_km_s, 3, 1)];
departure = sqrt(3) * [repmat(model.distance_km / a.departure.position_km, 3, 1); ...
    repmat(model.velocity_km_s / a.departure.velocity_km_s, 3, 1)];
radial = model.velocity_km_s / a.periapsis.radial_velocity_km_s;
target = sqrt(3) * model.velocity_km_s / a.target.velocity_km_s;
equality = 1e-9 * [departure; repmat(dynamics, nlp.n_nodes - 1, 1); ...
    radial; radial; repmat(target, 3, 1)];
inequality = 1e-9 * [repmat(model.distance_km / a.clearance.altitude_km, ...
    2 * nlp.n_nodes, 1); radial; radial; 1];
assert(all(isfinite([equality; inequality])), 'orb2ds:ConstraintTolerances', ...
    'Constraint tolerances exceed the supported floating-point scale.');
end
