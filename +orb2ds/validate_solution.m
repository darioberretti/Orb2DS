function validation = validate_solution(solution, problem, supplied)
%VALIDATE_SOLUTION Independently check compact shooting data and physical boundaries.
%
% PROTOTYPE:
%   validation = orb2ds.validate_solution(solution, problem, options)
%
% DESCRIPTION:
%   Repropagate each arc without STMs, locate radial extrema and impacts,
%   measure defects and body clearance, recompute the achieved outgoing Earth
%   asymptote, and check timing/orbit conditions. Also chain all burns from
%   the first node without resets and report its accumulated endpoint error.
%   Acceptance uses the explicitly declared multiple-shooting tolerances;
%   chained-closure diagnostics are reported separately because unstable
%   trajectories amplify local integration/defect errors.
%
% INPUT:
%   solution  Canonical compact solution or candidate; no database required.
%   problem   Current target, orbit and physical constraints.
%   options   Optional integration and physical acceptance tolerances.
% OUTPUT:
%   validation  Feasibility checks, physical residuals, compact per-node
%               defects, event extrema and separate chained diagnostics.
%               No sampled trajectories or solver callbacks are retained.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
solution = orb2ds.internal.check_record(solution);
orb2ds.internal.same_orbit(problem.orbit, solution.orbit);
model = problem.orbit.model;
scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
times = solution.nodes.time_days;
states = solution.nodes.state_post;
impulses = solution.nodes.delta_v_km_s;
count = numel(times);
defects = zeros(count - 1, 6);
complete = true;
minimum_earth = inf;
minimum_moon = inf;
chain = states(1, :).' ./ scale.';
chain_complete = true;
chain_minimum_earth = inf;
chain_minimum_moon = inf;
ode_options = odeset('RelTol', options.integration.relative_tolerance, ...
    'AbsTol', options.integration.absolute_tolerance, ...
    'Events', @(t, x) validation_events(t, x, model));
rhs = @(t, x) orb2ds.internal.rhs_CR3BP_3D(t, x, model.mu);
for index = 1:count - 1
    span = [times(index), times(index + 1)] / model.time_days;
    arc = ode113(rhs, span, states(index, :).' ./ scale.', ode_options);
    reached = arc.x(end) == span(end);
    complete = complete && reached;
    arrival = arc.y(:, end).' .* scale;
    expected = states(index + 1, :);
    expected(4:6) = expected(4:6) - impulses(index + 1, :);
    defects(index, :) = arrival - expected;
    samples = arc.y.';
    if isfield(arc, 'ye') && ~isempty(arc.ye)
        samples = [samples; arc.ye.'];
    end
    minimum_earth = min(minimum_earth, min(vecnorm(samples(:, 1:3) + ...
        [model.mu, 0, 0], 2, 2)) * model.distance_km - model.earth_radius_km);
    minimum_moon = min(minimum_moon, min(vecnorm(samples(:, 1:3) - ...
        [1 - model.mu, 0, 0], 2, 2)) * model.distance_km - model.moon_radius_km);
    if chain_complete
        chained = ode113(rhs, span, chain, ode_options);
        chain_complete = chained.x(end) == span(end);
        chain_samples = chained.y.';
        if isfield(chained, 'ye') && ~isempty(chained.ye)
            chain_samples = [chain_samples; chained.ye.'];
        end
        chain_minimum_earth = min(chain_minimum_earth, ...
            min(vecnorm(chain_samples(:, 1:3) + [model.mu, 0, 0], 2, 2)) ...
            * model.distance_km - model.earth_radius_km);
        chain_minimum_moon = min(chain_minimum_moon, ...
            min(vecnorm(chain_samples(:, 1:3) - [1 - model.mu, 0, 0], 2, 2)) ...
            * model.distance_km - model.moon_radius_km);
        chain = chained.y(:, end);
        if chain_complete
            chain(4:6) = chain(4:6) + impulses(index + 1, :).'/model.velocity_km_s;
        end
    end
end

% Compare the initial pre-burn state with the independently propagated orbit.
reference = problem.orbit.state_ref ./ scale.';
orbit_state = orb2ds.internal.propagate(reference, ...
    [0, solution.timing.departure_phase * problem.orbit.period_days / model.time_days], ...
    model, options) .* scale.';
initial_pre = states(1, :).';
initial_pre(4:6) = initial_pre(4:6) - impulses(1, :).';
departure_error = initial_pre - orbit_state;
closure = orb2ds.internal.propagate(reference, ...
    [0, problem.orbit.period_days / model.time_days], model, options) - reference;

% Recover actual escape geometry, independently of the NLP boundary formula.
terminal = orb2ds.internal.frames(states(end, :), times(end), model, 'to_eci');
[achieved, energy] = orb2ds.internal.outgoing_asymptote( ...
    terminal(1:3), terminal(4:6), model.gm_earth_km3_s2);
requested = orb2ds.internal.target_eci(problem.target, times(end));
target_error = norm(achieved - requested);
if ~isfinite(target_error)
    target_error = inf;
end
[earth_radial, earth_acceleration] = orb2ds.internal.radial_event( ...
    states(end, :).' ./ scale.', [-model.mu; 0; 0], model.mu);
moon_node = solution.events.moon_periapsis_node;
[moon_radial, moon_acceleration] = orb2ds.internal.radial_event( ...
    states(moon_node, :).' ./ scale.', [1 - model.mu; 0; 0], model.mu);
earth_radial = earth_radial * model.velocity_km_s;
moon_radial = moon_radial * model.velocity_km_s;

validation = struct('is_feasible', false, 'defects', defects, ...
    'max_position_defect_km', max(vecnorm(defects(:, 1:3), 2, 2)), ...
    'max_velocity_defect_km_s', max(vecnorm(defects(:, 4:6), 2, 2)), ...
    'departure_position_error_km', norm(departure_error(1:3)), ...
    'departure_velocity_error_km_s', norm(departure_error(4:6)), ...
    'min_earth_altitude_km', minimum_earth, 'min_moon_altitude_km', minimum_moon, ...
    'achieved_vinf_eci_km_s', achieved, 'requested_vinf_eci_km_s', requested, ...
    'target_error_km_s', target_error, 'earth_energy_km2_s2', energy, ...
    'earth_radial_speed_km_s', earth_radial, 'moon_radial_speed_km_s', moon_radial, ...
    'delta_v_m_s', 1000 * sum(vecnorm(impulses, 2, 2)));
tolerance = options.validation;
checks = struct();
checks.segment_endpoints_reached = complete;
checks.position_defects = validation.max_position_defect_km <= tolerance.position_tolerance_km;
checks.velocity_defects = validation.max_velocity_defect_km_s <= tolerance.velocity_tolerance_km_s;
checks.departure = validation.departure_position_error_km <= tolerance.position_tolerance_km && ...
    validation.departure_velocity_error_km_s <= tolerance.velocity_tolerance_km_s;
checks.orbit_closure = norm(closure(1:3)) * model.distance_km <= ...
    tolerance.orbit_closure_position_km && norm(closure(4:6)) * model.velocity_km_s <= ...
    tolerance.orbit_closure_velocity_km_s;
checks.target = target_error <= tolerance.target_tolerance_km_s;
checks.periapses = abs(earth_radial) <= tolerance.velocity_tolerance_km_s && ...
    abs(moon_radial) <= tolerance.velocity_tolerance_km_s && ...
    earth_acceleration >= 0 && moon_acceleration >= 0;
earth_margin = 0;
moon_margin = 0;
constraints = problem.constraints;
if isfield(constraints, 'min_earth_altitude_km')
    earth_margin = constraints.min_earth_altitude_km;
end
if isfield(constraints, 'min_moon_altitude_km')
    moon_margin = constraints.min_moon_altitude_km;
end
checks.clearance = minimum_earth >= earth_margin - tolerance.altitude_tolerance_km && ...
    minimum_moon >= moon_margin - tolerance.altitude_tolerance_km;
checks.impulse_policy = ~isfield(constraints, 'impulse_nodes') || ...
    ~strcmp(constraints.impulse_nodes, 'endpoints') || ...
    all(vecnorm(impulses(2:end - 1, :), 2, 2) <= tolerance.velocity_tolerance_km_s);
[checks.timing, validation.time_violations_days] = check_timing(solution, constraints, tolerance);
validation.checks = checks;
validation.is_feasible = all(cell2mat(struct2cell(checks)));

% Chained propagation is additional evidence, kept distinct from node defects.
chain_physical = chain.' .* scale;
validation.chained = struct('reached_final_epoch', chain_complete, ...
    'endpoint_position_error_km', norm(chain_physical(1:3) - states(end, 1:3)), ...
    'endpoint_velocity_error_km_s', norm(chain_physical(4:6) - states(end, 4:6)), ...
    'closes_within_local_tolerances', false);
validation.chained.closes_within_local_tolerances = chain_complete && ...
    validation.chained.endpoint_position_error_km <= tolerance.position_tolerance_km && ...
    validation.chained.endpoint_velocity_error_km_s <= tolerance.velocity_tolerance_km_s;
chain_target_error = inf;
if chain_complete
    chain_inertial = orb2ds.internal.frames(chain_physical, times(end), model, 'to_eci');
    chain_asymptote = orb2ds.internal.outgoing_asymptote( ...
        chain_inertial(1:3), chain_inertial(4:6), model.gm_earth_km3_s2);
    chain_target_error = norm(chain_asymptote - requested);
end
validation.chained.target_error_km_s = chain_target_error;
validation.chained.min_earth_altitude_km = chain_minimum_earth;
validation.chained.min_moon_altitude_km = chain_minimum_moon;
validation.chained.is_feasible = validation.is_feasible && ...
    validation.chained.closes_within_local_tolerances && ...
    chain_target_error <= tolerance.target_tolerance_km_s && ...
    chain_minimum_earth >= earth_margin - tolerance.altitude_tolerance_km && ...
    chain_minimum_moon >= moon_margin - tolerance.altitude_tolerance_km;
end

function [value, terminal, direction] = validation_events(~, state, model)
%VALIDATION_EVENTS Locate radial extrema and stop before a physical collision.
earth = state(1:3) + [model.mu; 0; 0];
moon = state(1:3) - [1 - model.mu; 0; 0];
value = [dot(earth, state(4:6)); dot(moon, state(4:6)); ...
    norm(earth) - model.earth_radius_km / model.distance_km; ...
    norm(moon) - model.moon_radius_km / model.distance_km];
terminal = [0; 0; 1; 1];
direction = [0; 0; -1; -1];
end

function [valid, violations] = check_timing(solution, constraints, tolerance)
%CHECK_TIMING Apply all user caps and initial-event couplings without defaults.
times = solution.nodes.time_days;
flight = times(end) - times(1);
wait = 0;
has_event = isfield(constraints, 'initial_time_days') || isfield(constraints, 'initial_phase');
violations = zeros(0, 1);
if has_event
    assert(isfield(solution.timing, 'wait_days') && isscalar(solution.timing.wait_days), ...
        'orb2ds:Timing', 'A solution with an initial event must report its waiting duration.');
    wait = solution.timing.wait_days;
    violations(end + 1, 1) = -wait;
    if isfield(constraints, 'max_wait_time_days')
        violations(end + 1, 1) = wait - constraints.max_wait_time_days;
    end
    if isfield(constraints, 'initial_time_days')
        violations(end + 1, 1) = abs(times(1) - constraints.initial_time_days - wait);
    end
    if isfield(constraints, 'initial_phase')
        expected = constraints.initial_phase + wait / solution.orbit.period_days;
        difference = mod(solution.timing.departure_phase - expected + 0.5, 1) - 0.5;
        violations(end + 1, 1) = abs(difference) * solution.orbit.period_days;
    end
end
if isfield(constraints, 'max_transfer_time_days')
    violations(end + 1, 1) = flight - constraints.max_transfer_time_days;
end
if isfield(constraints, 'max_total_time_days')
    violations(end + 1, 1) = flight + wait - constraints.max_total_time_days;
end
valid = flight > 0 && all(violations <= tolerance.time_tolerance_days);
end
