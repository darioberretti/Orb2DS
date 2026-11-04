function [boundary, energy_guard] = terminal_boundary(state, epoch_tu, nlp, derivative)
%TERMINAL_BOUNDARY Enforce Earth periapsis and the outgoing excess-velocity vector.
%
% INPUT:
%   state       Normalized barycentric rotating post-burn 6-vector.
%   epoch_tu    Local epoch [TU]; complex steps and symbolic values are valid.
%   nlp         Runtime problem, target and physical model.
%   derivative  Optional state derivative for symbolic evaluation.
% OUTPUT:
%   boundary    Four residuals [VU]: radial speed and outgoing-vector error.
%   energy_guard Inequality <=0 retaining the exact hyperbolic domain.
%
%   trial_asymptote supplies a real C2 extension for nonhyperbolic trials.
%   The energy guard excludes that extension from physically accepted roots.

model = nlp.model;
scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
inertial = orb2ds.internal.frames(state(:).' .* scale, ...
    epoch_tu * model.time_days, model, 'to_eci');
position = inertial(1:3).' / model.distance_km;
velocity = inertial(4:6).' / model.velocity_km_s;
target = orb2ds.internal.target_eci(nlp.problem.target, epoch_tu * model.time_days);
target = target / model.velocity_km_s;
magnitude = norm(nlp.problem.target.vinf_km_s) / model.velocity_km_s;
[outgoing, energy_guard] = orb2ds.internal.trial_asymptote( ...
    position, velocity, 1 - model.mu, magnitude);
if nargin < 4
    derivative = orb2ds.internal.rhs_CR3BP_3D(0, state, model.mu);
end
radial = orb2ds.internal.radial_event(state, [-model.mu; 0; 0], model.mu, derivative);
boundary = [radial; outgoing - target];
end
