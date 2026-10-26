function [candidates, diagnostics] = find_legs(problem, supplied)
%FIND_LEGS Match reusable orbit-Moon encounters to target-dependent Earth legs.
%
% PROTOTYPE:
%   [candidates, diagnostics] = orb2ds.find_legs(problem, options)
%
% DESCRIPTION:
%   Retain the thesis altitude search, tangent Lambert construction, lunar
%   speed/turning-angle screening and Earth-burn ranking. Each Earth-side
%   candidate selects its closest feasible lunar speed. Unlike the historical
%   table, local boundary velocity and incoming asymptotic velocity have
%   separate meanings. All calculations share the supplied physical model.
%
% INPUT:
%   problem  Orbit, target, loaded canonical database, optional constraints.
%   options  Optional numerical settings; patching limits bound the search
%            only. RTH seed construction uses the target at local epoch zero;
%            optimization always evaluates its actual final-epoch direction.
% OUTPUT:
%   candidates   Compact ordered structure array; assembly needs no database.
%   diagnostics  Numerical search bounds, attempted altitudes and row counts.
%                Empty candidates means no seed found in this search.

if nargin < 2
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
database = orb2ds.internal.check_database(problem.database);
orb2ds.internal.same_orbit(problem.orbit, database.orbit);
validateattributes(options.patching.n_perigee, {'double'}, {'scalar', 'integer', '>=', 3});
validateattributes(options.patching.n_moon, {'double'}, {'scalar', 'integer', '>=', 2});
validateattributes(options.patching.altitude_factor, {'double'}, {'scalar', '>', 1});
validateattributes(options.patching.max_altitude_trials, {'double'}, {'scalar', 'integer', 'positive'});
height = options.patching.start_altitude_km;
if isfield(problem.constraints, 'min_earth_altitude_km')
    height = max(height, problem.constraints.min_earth_altitude_km);
end
assert(height > 0, 'orb2ds:Patching', 'The altitude search must start above the surface.');
candidates = struct([]);
diagnostics = struct('altitudes_km', [], 'candidate_counts', [], ...
    'settings', options.patching, 'database_rows', numel(database.encounters.row_id));
if ~any(all(isfinite(database.encounters.velocity_infinity_rth_km_s), 2))
    diagnostics.reason = 'no_hyperbolic_encounters_in_database';
    return
end
found = false;
for trial = 1:options.patching.max_altitude_trials
    at_height = evaluate_altitude(problem, database, height, options);
    diagnostics.altitudes_km(end + 1, 1) = height;
    diagnostics.candidate_counts(end + 1, 1) = numel(at_height);
    if options.output.display
        fprintf('orb2ds matching: altitude %.3f km, %d candidates\n', height, numel(at_height));
    end
    if isempty(at_height)
        if found
            break
        end
    elseif ~found || at_height(1).ranking.earth_delta_v_km_s < ...
            candidates(1).ranking.earth_delta_v_km_s
        candidates = at_height;
        found = true;
    else
        break
    end
    height = height * options.patching.altitude_factor;
end
end

function candidates = evaluate_altitude(problem, database, height, options)
%EVALUATE_ALTITUDE Sample the thesis Earth-perigee and Moon-phase geometry.
model = problem.orbit.model;
target = orb2ds.internal.target_eci(problem.target, 0);
[positions, velocities] = orb2ds.internal.rp_circle_from_vinfplus( ...
    target, model.earth_radius_km + height, model.gm_earth_km3_s2, options.patching.n_perigee);
entries = database.encounters;
incoming_speeds = vecnorm(entries.velocity_infinity_rth_km_s, 2, 2);
moon_minimum = model.moon_radius_km;
if isfield(problem.constraints, 'min_moon_altitude_km')
    moon_minimum = moon_minimum + problem.constraints.min_moon_altitude_km;
end
candidates = struct([]);
for perigee = 1:size(positions, 1)
    earth_position = positions(perigee, :).';
    earth_post_velocity = velocities(perigee, :).';
    theta0 = mod(atan2(earth_position(2), earth_position(1)) - pi, 2 * pi);
    if theta0 > 1.5 * pi
        theta0 = theta0 - 2 * pi;
    end
    angles = theta0 - (0:options.patching.n_moon - 1) * pi / (2 * options.patching.n_moon);
    for angle = angles
        radial = [cos(angle); sin(angle); 0];
        transverse = [-sin(angle); cos(angle); 0];
        moon_position = model.distance_km * radial;
        [duration, initial_velocity, arrival_velocity, success] = ...
            orb2ds.internal.perigee_lambert(moon_position, earth_position, model, options);
        if ~success
            continue
        end
        outgoing = [dot(initial_velocity, radial); ...
            dot(initial_velocity, transverse) - model.velocity_km_s; initial_velocity(3)];
        speed = norm(outgoing);
        neighbors = find(abs(incoming_speeds - speed) <= options.patching.speed_tolerance_km_s);
        if isempty(neighbors)
            continue
        end
        incoming = entries.velocity_infinity_rth_km_s(neighbors, :);
        cosine = sum(incoming .* outgoing.', 2) ./ (incoming_speeds(neighbors) * speed);
        maximum_sine = 1 ./ (1 + moon_minimum * incoming_speeds(neighbors).^2 / model.gm_moon_km3_s2);
        allowed = cosine >= 1 - 2 * maximum_sine.^2;
        neighbors = neighbors(allowed);
        if isempty(neighbors)
            continue
        end
        [mismatch, closest] = min(abs(incoming_speeds(neighbors) - speed));
        row = neighbors(closest);
        entry = struct('row_id', row, 'departure_phase', entries.departure_phase(row), ...
            'delta_v_km_s', entries.delta_v_km_s(row, :), ...
            'duration_days', entries.duration_days(row), ...
            'state_entry', entries.state_entry(row, :), ...
            'velocity_infinity_rth_km_s', entries.velocity_infinity_rth_km_s(row, :));
        earth = struct('initial_position_km', moon_position, 'initial_velocity_km_s', initial_velocity, ...
            'periapsis_position_km', earth_position, 'periapsis_velocity_pre_km_s', arrival_velocity, ...
            'delta_v_km_s', earth_post_velocity - arrival_velocity, ...
            'duration_days', duration, 'moon_angle_rad', angle, ...
            'outgoing_moon_asymptote_km_s', outgoing);
        candidate = struct('schema_version', 1, 'orbit', problem.orbit, ...
            'orbit_moon', entry, 'moon_earth', earth, ...
            'ranking', struct('earth_delta_v_km_s', norm(earth.delta_v_km_s), ...
            'speed_mismatch_km_s', mismatch, 'altitude_km', height), ...
            'provenance', struct('database_row', row, 'perigee_sample', perigee, ...
            'seed_target', problem.target));
        if isempty(candidates)
            candidates = candidate;
        else
            candidates(end + 1, 1) = candidate;
        end
    end
end
if ~isempty(candidates)
    cost = arrayfun(@(candidate) candidate.ranking.earth_delta_v_km_s, candidates);
    [~, order] = sort(cost, 'ascend');
    candidates = candidates(order(1:min(numel(order), options.patching.n_candidates)));
end
end
