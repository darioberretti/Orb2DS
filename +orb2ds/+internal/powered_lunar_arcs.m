function [inbound, outbound, earth_arc, burn, patch] = powered_lunar_arcs( ...
    problem, candidate, peri_time, options)
%POWERED_LUNAR_ARCS Refine a powered conic patch at finite lunar crossings.
%
%   Build rotating CR3BP arcs on either side of one shared perilune and a
%   tangent Earth-two-body arc from the outbound crossing. Recover the
%   outgoing osculating asymptote at that finite crossing and update the
%   patch with a limited fixed-point iteration. Times are local days and
%   states are physical km/km/s. Empty inbound means no usable patch.
%   peri_time is the sampled perilune epoch before departure anchoring.
%   burn holds lunar rotating and Earth inertial vectors [km/s].

inbound = [];
outbound = [];
earth_arc = [];
burn = [];
patch = struct();
model = problem.orbit.model;
minimum = model.moon_radius_km;
if isfield(problem.constraints, 'min_moon_altitude_km')
    minimum = minimum + problem.constraints.min_moon_altitude_km;
end
boundary = model.encounter_radius_km;
if minimum >= boundary
    return
end
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
center = [(1 - model.mu) * model.distance_km; 0; 0];
omega = 1 / (86400 * model.time_days);
earth = candidate.moon_earth;
incoming = candidate.orbit_moon.velocity_infinity_rth_km_s(:);
outgoing = earth.outgoing_moon_asymptote_km_s(:);
flight = candidate.timing.transfer_days;
orbit_days = candidate.orbit_moon.duration_days;
wait = candidate.orbit_moon.wait_days;
phase = candidate.orbit_moon.departure_phase;
elapsed = flight - orbit_days - earth.duration_days;
earth_radius = norm(earth.periapsis_position_km);
sample = candidate.provenance.perigee_sample;
target_epoch = earth.target_epoch_days;
is_rth = strcmp(problem.target.frame, 'earth_sun_rth');
options_at_boundary = odeset('RelTol', options.integration.relative_tolerance, ...
    'AbsTol', options.integration.absolute_tolerance, 'Events', @crossing);
horizon = options.patching.flyby_horizon_days / model.time_days;
rhs = @(t, x) orb2ds.internal.rhs_CR3BP_3D(t, x, model.mu);

% Iterate on asymptotes expressed in the inertial axes at perilune.
for iteration = 1:options.patching.target_iterations
    aligned = rotate(incoming, -elapsed / model.time_days);
    [cost, ~, r, v_pre, v_post] = orb2ds.internal.powered_perilune( ...
        aligned.', outgoing.', model.gm_moon_km3_s2, minimum, boundary, 80);
    if ~isfinite(cost) || norm(r) >= boundary
        break
    end
    r = r.';
    transport = omega * cross([0; 0; 1], r);
    pre = [center + r; v_pre.' - transport];
    post = [center + r; v_post.' - transport];
    back = ode113(rhs, [0, -horizon], pre ./ scale, options_at_boundary);
    forward = ode113(rhs, [0, horizon], post ./ scale, options_at_boundary);
    if ~isfield(back, 'xe') || ~isfield(forward, 'xe') || ...
            isempty(back.xe) || isempty(forward.xe) || ...
            back.xe(end) >= 0 || forward.xe(end) <= 0
        break
    end
    updated_elapsed = -back.xe(end) * model.time_days;
    raw_departure = peri_time - updated_elapsed - orbit_days;
    timing = orb2ds.internal.seed_timing(problem, raw_departure, phase, wait, flight);
    entry_time = timing.departure_days + orbit_days;
    anchored_peri = entry_time + updated_elapsed;
    exit_time = anchored_peri + forward.xe(end) * model.time_days;
    exit_rotating = forward.ye(:, end) .* scale;
    earth_leg = orb2ds.internal.earth_return_leg( ...
        problem, exit_rotating, exit_time, earth_radius, sample, target_epoch, false, options);
    if isempty(earth_leg)
        break
    end
    moon_eci = orb2ds.internal.frames([center.', 0, 0, 0], exit_time, model, 'to_eci');
    relative_position = earth_leg.arc.initial_state(1:3) - moon_eci(1:3).';
    relative_velocity = earth_leg.arc.initial_state(4:6) - moon_eci(4:6).';
    updated = orb2ds.internal.outgoing_asymptote(relative_position, relative_velocity, ...
        model.gm_moon_km3_s2);
    if any(~isfinite(updated)) || dot(relative_position, relative_velocity) <= 0
        break
    end
    angle = model.moon_angle_ref_rad + anchored_peri / model.time_days;
    updated = rotate(updated, -angle);
    final_time = earth_leg.arc.end_days;
    flight = final_time - timing.departure_days;
    updated_timing = orb2ds.internal.seed_timing(problem, raw_departure, phase, wait, flight);
    wait_change = abs(updated_timing.wait_days - timing.wait_days);
    timing.transfer_days = flight;
    timing.total_days = flight + timing.wait_days;
    timing.time_excess_days = updated_timing.time_excess_days;
    if isfield(problem.constraints, 'max_total_time_days')
        timing.time_excess_days = max(timing.time_excess_days, ...
            timing.total_days - problem.constraints.max_total_time_days);
    end
    timing.meets_time_caps = timing.time_excess_days <= 1e-10;

    % Keep the last reconstructible iterate, including its velocity gap.
    inbound = arc('cr3bp', entry_time, anchored_peri, anchored_peri, pre);
    outbound = arc('cr3bp', anchored_peri, exit_time, anchored_peri, post);
    earth_arc = earth_leg.arc;
    burn = struct('lunar_km_s', post(4:6) - pre(4:6), ...
        'earth_eci_km_s', earth_leg.delta_v_eci_km_s);
    target_error = earth_leg.target_epoch_error_km_s;
    timing.target_epoch_error_km_s = target_error;
    timing.phase = phase;
    patch = struct('iterations', iteration, 'outgoing_asymptote_error_km_s', ...
        norm(updated - outgoing), 'entry_time_error_days', abs(updated_elapsed - elapsed), ...
        'incoming_asymptote_perilune_axes_km_s', aligned, ...
        'outgoing_asymptote_perilune_axes_km_s', outgoing, ...
        'earth_leg_asymptote_perilune_axes_km_s', updated, 'timing', timing);
    % The patched-conic and CR3BP states can retain a finite SOI defect.
    if patch.outgoing_asymptote_error_km_s <= 1e-7 && ...
            patch.entry_time_error_days <= 1e-7 && target_error <= 1e-8 && wait_change <= 1e-8
        break
    end
    elapsed = updated_elapsed;
    outgoing = updated;
    if is_rth
        target_epoch = final_time;
    end
end

    function [value, terminal, direction] = crossing(~, state)
        value = norm(state(1:3) - center / model.distance_km) - boundary / model.distance_km;
        terminal = 1;
        direction = 0;
    end
end

function result = arc(kind, start, stop, epoch, state)
%ARC Store one physical propagation recipe.
result = struct('kind', kind, 'start_days', start, 'end_days', stop, ...
    'initial_days', epoch, 'initial_state', state);
end

function vector = rotate(vector, angle)
%ROTATE Express an inertial vector on axes rotated about the lunar orbit normal.
c = cos(angle);
s = sin(angle);
vector = [c * vector(1) - s * vector(2); s * vector(1) + c * vector(2); vector(3)];
end
