function boundary = terminal_boundary(state, epoch_tu, nlp)
%TERMINAL_BOUNDARY Impose the prescribed outgoing hyperbola at Earth periapsis.
%
% PROTOTYPE:
%   boundary = orb2ds.internal.terminal_boundary(state, epoch_tu, nlp)
% INPUT:
%   state     Six-component normalized barycentric rotating post-burn state.
%   epoch_tu  Local epoch in model time units; also accepts complex steps.
%   nlp       Runtime context with the current target and physical model.
% OUTPUT:
%   boundary  Four normalized residuals: radial speed and required periapsis
%             velocity mismatch in inertial axes.
%
%   Four equalities are equivalent to radial stationarity and three outgoing
%   v-infinity components. Expressing the required periapsis velocity using
%   the requested excess speed keeps evaluation real for nonhyperbolic trial
%   states. Accepted solutions are checked independently via achieved energy
%   and asymptotic velocity. No sqrt of trial-state energy is required here.

model = nlp.model;
scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
inertial = orb2ds.internal.frames(state(:).' .* scale, ...
    epoch_tu * model.time_days, model, 'to_eci');
position = inertial(1:3).' / model.distance_km;
velocity = inertial(4:6).' / model.velocity_km_s;
radius = sqrt(sum(position.^2));
target = orb2ds.internal.target_eci(nlp.problem.target, epoch_tu * model.time_days);
target = target / model.velocity_km_s;
magnitude = norm(nlp.problem.target.vinf_km_s) / model.velocity_km_s;
eccentricity = 1 + radius * magnitude^2 / (1 - model.mu);
periapsis_speed = sqrt(magnitude^2 + 2 * (1 - model.mu) / radius);
required = periapsis_speed * (eccentricity * target / magnitude + position / radius) ...
    / sqrt(eccentricity^2 - 1);
radial = orb2ds.internal.radial_event(state, [-model.mu; 0; 0], model.mu);
boundary = [radial; velocity - required];
end
