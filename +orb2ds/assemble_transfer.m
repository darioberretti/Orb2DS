function transfer = assemble_transfer(problem, candidate, supplied)
%ASSEMBLE_TRANSFER Reconstruct compact physical arcs and a finite lunar passage.
%
% PROTOTYPE:
%   transfer = orb2ds.assemble_transfer(problem, candidate, options)
%
% DESCRIPTION:
%   Extract the thesis perilune/backward-forward flyby and joined CR3BP/
%   Earth-two-body seed construction. Keep the actual SOI entry, perilune
%   and exit epochs, patch defects, and terminal pre/post-impulse distinction.
%   Use the canonical Moon velocity, not the historical inverse-speed offset.
%
% INPUT:
%   problem    Current physical problem; no database access is required.
%   candidate  One compact matched-leg record.
%   options    Optional numerical settings.
% OUTPUT:
%   transfer   Compact propagation recipes and event anchors, or empty when
%              this candidate has no reconstructible finite lunar passage.
%              Units km, km/s and local days; no sampled trajectories.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
orb2ds.internal.same_orbit(problem.orbit, candidate.orbit);
model = problem.orbit.model;
transfer = [];
incoming = candidate.orbit_moon.velocity_infinity_rth_km_s(:);
outgoing = candidate.moon_earth.outgoing_moon_asymptote_km_s(:);
speed = (norm(incoming) + norm(outgoing)) / 2;
turn = acos(max(-1, min(1, dot(incoming, outgoing) / (norm(incoming) * norm(outgoing)))));
if turn <= 1e-12 || pi - turn <= 1e-12
    return
end
radius = model.gm_moon_km3_s2 / speed^2 * (1 / sin(turn / 2) - 1);
minimum = model.moon_radius_km;
if isfield(problem.constraints, 'min_moon_altitude_km')
    minimum = minimum + problem.constraints.min_moon_altitude_km;
end
if radius < minimum
    return
end

% Preserve the historical bisector construction, with one consistent GM.
peri_position = radius / (2 * speed * sin(turn / 2)) * (incoming - outgoing);
peri_velocity = sqrt(speed^2 + 2 * model.gm_moon_km3_s2 / radius) / ...
    (2 * speed * cos(turn / 2)) * (incoming + outgoing);
omega = 1 / (86400 * model.time_days);
state_peri = [[(1 - model.mu) * model.distance_km; 0; 0] + peri_position; ...
    peri_velocity - omega * cross([0; 0; 1], peri_position)];
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
peri_time = (candidate.moon_earth.moon_angle_rad - model.moon_angle_ref_rad) * model.time_days;
initial = state_peri ./ scale;
ode_options = odeset('RelTol', options.integration.relative_tolerance, ...
    'AbsTol', options.integration.absolute_tolerance, ...
    'Events', @(t, x) flyby_boundary(t, x, model));
rhs = @(t, x) orb2ds.internal.rhs_CR3BP_3D(t, x, model.mu);
horizon = options.patching.flyby_horizon_days / model.time_days;
backward = ode113(rhs, [0, -horizon], initial, ode_options);
forward = ode113(rhs, [0, horizon], initial, ode_options);
if isempty(backward.xe) || isempty(forward.xe)
    return
end
entry_time = peri_time + backward.xe(end) * model.time_days;
exit_time = peri_time + forward.xe(end) * model.time_days;
final_time = peri_time + candidate.moon_earth.duration_days;
if final_time <= exit_time
    return
end
departure_time = entry_time - candidate.orbit_moon.duration_days;
departure = orb2ds.internal.propagate(problem.orbit.state_ref ./ scale, ...
    [0, candidate.orbit_moon.departure_phase * problem.orbit.period_days / model.time_days], ...
    model, options) .* scale;
departure(4:6) = departure(4:6) + candidate.orbit_moon.delta_v_km_s(:);
recipe = struct('kind', '', 'start_days', 0, 'end_days', 0, ...
    'initial_days', 0, 'initial_state', zeros(6, 1));
arcs = repmat(recipe, 3, 1);
arcs(1) = struct('kind', 'cr3bp', 'start_days', departure_time, 'end_days', entry_time, ...
    'initial_days', departure_time, 'initial_state', departure);
arcs(2) = struct('kind', 'cr3bp', 'start_days', entry_time, 'end_days', exit_time, ...
    'initial_days', peri_time, 'initial_state', state_peri);
arcs(3) = struct('kind', 'earth_two_body', 'start_days', exit_time, 'end_days', final_time, ...
    'initial_days', peri_time, 'initial_state', ...
    [candidate.moon_earth.initial_position_km; candidate.moon_earth.initial_velocity_km_s]);
transfer = struct('schema_version', 1, 'orbit', problem.orbit, 'arcs', arcs, ...
    'events', struct('moon_entry_days', entry_time, 'moon_periapsis_days', peri_time, ...
    'moon_exit_days', exit_time, 'earth_periapsis_days', final_time), ...
    'departure_phase', candidate.orbit_moon.departure_phase, ...
    'departure_impulse_km_s', candidate.orbit_moon.delta_v_km_s, ...
    'terminal_impulse_eci_km_s', candidate.moon_earth.delta_v_km_s, ...
    'integration', options.integration, 'provenance', candidate.provenance);
transfer.provenance.flyby_seed = ...
    'historical mean-speed bisector; periapsis stationarity is enforced in the NLP';
end

function [value, terminal, direction] = flyby_boundary(~, state, model)
%FLYBY_BOUNDARY Stop at either crossing of the declared lunar patch boundary.
value = norm(state(1:3) - [1 - model.mu; 0; 0]) - ...
    model.encounter_radius_km / model.distance_km;
terminal = 1;
direction = 0;
end
