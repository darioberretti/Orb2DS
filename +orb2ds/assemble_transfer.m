function transfer = assemble_transfer(problem, candidate, supplied)
%ASSEMBLE_TRANSFER Reconstruct compact physical arcs and a finite lunar passage.
%
% PROTOTYPE:
%   transfer = orb2ds.assemble_transfer(problem, candidate, options)
%
% DESCRIPTION:
%   Construct a lunar flyby by propagating backward and forward from a
%   mean-speed bisector anchor. Join the orbit-Moon and flyby CR3BP arcs to
%   an Earth-two-body arrival arc. Retain lunar entry/closest-approach/exit
%   epochs, patch defects and terminal pre/post-impulse states. Frame
%   transforms use the circular lunar velocity from the supplied model.
%   Rebuild departure at the matched phase and anchor epochs after the chosen
%   wait. For a fixed epoch, refit the Earth leg from the finite lunar exit.
%   Update RTH legs at their reconstructed arrival epoch. Exact
%   timing-cap excess and remaining lunar alignment error are diagnostics;
%   patch defects are left for the NLP, not hidden by moving mesh nodes.
%   Powered candidates use two lunar arcs with a shared perilune, a
%   vector impulse and a tangent Lambert leg from the finite lunar exit.
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
% Older matched records can carry the requested phase in orbit_moon.
if isfield(candidate.provenance, 'database_departure_phase')
    candidate.orbit_moon.departure_phase = candidate.provenance.database_departure_phase;
end
if isfield(candidate.provenance, 'patching_method')
    powered = strcmp(candidate.provenance.patching_method, 'powered');
else
    % Match records without a method identify powered candidates by score.
    powered = isfield(candidate.ranking, 'powered_score_km_s');
end
if powered
    transfer = orb2ds.internal.assemble_powered_transfer(problem, candidate, options);
    return
end
wait = 0;
if isfield(candidate.orbit_moon, 'wait_days')
    wait = candidate.orbit_moon.wait_days;
end
has_epoch = isfield(problem.constraints, 'initial_time_days');
for iteration = 1:options.patching.target_iterations
    [transfer, exit_state] = assemble_arcs(problem, candidate, options);
    if isempty(transfer)
        return
    end
    if has_epoch
        [transfer, timing] = anchor_ballistic_arcs(problem, transfer, exit_state, candidate, wait, options);
        if isempty(transfer)
            return
        end
        break
    end
    raw_departure = transfer.arcs(1).start_days;
    flight = transfer.arcs(end).end_days - raw_departure;
    timing = orb2ds.internal.seed_timing(problem, raw_departure, ...
        transfer.departure_phase, wait, flight);

    if ~strcmp(problem.target.frame, 'earth_sun_rth')
        break
    end
    final_time = transfer.events.earth_periapsis_days;
    achieved_target = orb2ds.internal.target_eci(problem.target, ...
        candidate.moon_earth.target_epoch_days);
    target = orb2ds.internal.target_eci(problem.target, final_time);
    error = norm(achieved_target - target);
    timing.target_epoch_error_km_s = error;
    if error <= 1e-8 || iteration == options.patching.target_iterations
        break
    end
    [earth, success] = orb2ds.internal.earth_seed_leg(problem, ...
        candidate.ranking.altitude_km, candidate.provenance.perigee_sample, ...
        candidate.moon_earth.moon_angle_rad, final_time, options);
    if ~success
        transfer = [];
        return
    end
    candidate.moon_earth = earth;
end
transfer.wait_days = timing.wait_days;
timing.phase = transfer.departure_phase;
timing.meets_time_caps = timing.time_excess_days <= 1e-10;
transfer.provenance.seed_screening = timing;
if options.output.display
    fprintf('\n[Orb2DS] Initial guess\n\n');
    fprintf('  Departure phase                : %.9g\n', timing.phase);
    fprintf('  Departure epoch [days]         : %.9g\n', timing.departure_days);
    fprintf('  Waiting time [days]            : %.6g\n', timing.wait_days);
    fprintf('  Flight time [days]             : %.6g\n', timing.transfer_days);
    fprintf('  Total time [days]              : %.6g\n', timing.total_days);
    fprintf('  Time-cap excess [days]         : %.6g\n', timing.time_excess_days);
    fprintf('  Lunar epoch alignment [rad]    : %.6g\n', timing.moon_phase_mismatch_rad);
end
end

function [transfer, timing] = anchor_ballistic_arcs(problem, transfer, exit_state, candidate, wait, options)
%ANCHOR_BALLISTIC_ARCS Refit the tangent Earth leg from the shifted exit.
%   exit_state is the finite SOI crossing in rotating km and km/s. Only the
%   two rotating arcs use a time shift. Return [] if no tangent fit exists
%   on the sampled perigee circle.
constraints = problem.constraints;
raw_departure = transfer.arcs(1).start_days;
raw_exit = transfer.events.moon_exit_days;
phase = transfer.departure_phase;
flight = transfer.events.earth_periapsis_days - raw_departure;
radius = norm(candidate.moon_earth.periapsis_position_km);
sample = candidate.provenance.perigee_sample;
target_epoch = candidate.moon_earth.target_epoch_days;

% Recompute the Earth leg if the new duration changes waiting or the RTH target.
for iteration = 1:options.patching.target_iterations
    timing = orb2ds.internal.seed_timing(problem, raw_departure, phase, wait, flight);
    shift = timing.departure_days - raw_departure;
    exit_time = raw_exit + shift;
    earth = orb2ds.internal.earth_return_leg( ...
        problem, exit_state, exit_time, radius, sample, target_epoch, true, options);
    if isempty(earth)
        transfer = [];
        return
    end
    sample = earth.perigee_sample;
    arrival = earth.arc.end_days;
    flight = arrival - timing.departure_days;
    updated = orb2ds.internal.seed_timing(problem, raw_departure, phase, wait, flight);
    target_error = earth.target_epoch_error_km_s;
    if abs(updated.wait_days - timing.wait_days) <= 1e-10 && target_error <= 1e-8
        break
    end
    target_epoch = arrival;
end

for index = 1:2
    transfer.arcs(index).start_days = transfer.arcs(index).start_days + shift;
    transfer.arcs(index).end_days = transfer.arcs(index).end_days + shift;
    transfer.arcs(index).initial_days = transfer.arcs(index).initial_days + shift;
end
transfer.arcs(3) = earth.arc;
transfer.events = struct('moon_entry_days', transfer.arcs(1).end_days, ...
    'moon_periapsis_days', transfer.arcs(2).initial_days, 'moon_exit_days', exit_time, ...
    'earth_periapsis_days', arrival);
transfer.terminal_impulse_eci_km_s = earth.delta_v_eci_km_s;
transfer.provenance.earth_perigee_sample = sample;
timing.transfer_days = flight;
timing.total_days = flight + timing.wait_days;
timing.time_excess_days = updated.time_excess_days;
if isfield(constraints, 'max_total_time_days')
    timing.time_excess_days = max(timing.time_excess_days, timing.total_days - constraints.max_total_time_days);
end
if strcmp(problem.target.frame, 'earth_sun_rth')
    timing.target_epoch_error_km_s = target_error;
end
end

function [transfer, exit_state] = assemble_arcs(problem, candidate, options)
%ASSEMBLE_ARCS Reconstruct finite flyby boundaries and the three physical arcs.
%
% DESCRIPTION:
%   Build a mean-speed bisector perilune state and integrate CR3BP motion
%   to both lunar boundary crossings. Preserve the sampled inertial lunar
%   azimuth in the raw timeline. Return the finite rotating exit state too.
% INPUT:
%   problem/candidate  Checked request and one compact matched-leg record.
%   options            Resolved numerical integration/patching settings.
% OUTPUT:
%   transfer  Compact km/km/s/day arc recipes, or [] if the finite passage
%             cannot be reconstructed inside the declared flyby horizon.
%   exit_state  Finite SOI exit in rotating km and km/s.
model = problem.orbit.model;
transfer = [];
exit_state = [];
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

% Construct the flyby anchor from mean incoming/outgoing speed and bisectors.
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
if final_time <= exit_time && ~isfield(problem.constraints, 'initial_time_days')
    return
end
exit_state = forward.ye(:, end) .* scale;
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
    'mean-speed bisector; periapsis stationarity is enforced in the NLP';
end

function [value, terminal, direction] = flyby_boundary(~, state, model)
%FLYBY_BOUNDARY Stop at either crossing of the declared lunar patch boundary.
value = norm(state(1:3) - [1 - model.mu; 0; 0]) - ...
    model.encounter_radius_km / model.distance_km;
terminal = 1;
direction = 0;
end
