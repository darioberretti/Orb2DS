function [candidates, diagnostics] = find_legs(problem, supplied)
%FIND_LEGS Match reusable orbit-Moon encounters to target-dependent Earth legs.
%
% PROTOTYPE:
%   [candidates, diagnostics] = orb2ds.find_legs(problem, options)
%
% DESCRIPTION:
%   Search Earth-perigee altitudes, construct tangent Lambert legs, screen
%   lunar speed/turning angles.
%   Shortlist departure phases, expand allowed orbit-wait replicas and rank
%   matches by time-cap excess, lunar epoch alignment and estimated Earth
%   burn. Without timing constraints this reduces to Earth-burn ranking.
%   Local encounter-boundary velocity and incoming asymptotic velocity are
%   separate quantities. All calculations use the supplied physical model.
%
% INPUT:
%   problem  Orbit, target, loaded canonical database, optional constraints.
%   options  Optional numerical settings; patching limits bound the search
%            only. RTH legs update their target at estimated arrival epochs.
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
departures = orb2ds.internal.seed_departures(problem, database.encounters);
diagnostics.departure_row_count = numel(unique(departures.row));
diagnostics.departure_phase_grid = unique(database.encounters.departure_phase(departures.row));
diagnostics.departure_replicas = numel(departures.row);
for trial = 1:options.patching.max_altitude_trials
    at_height = evaluate_altitude(problem, database, departures, height, options);
    diagnostics.altitudes_km(end + 1, 1) = height;
    diagnostics.candidate_counts(end + 1, 1) = numel(at_height);
    if options.output.display
        fprintf('orb2ds matching: altitude %.3f km, %d candidates\n', height, numel(at_height));
    end
    if isempty(at_height)
        if found
            break
        end
    elseif ~found || better_rank(at_height(1), candidates(1))
        candidates = at_height;
        found = true;
    else
        break
    end
    height = height * options.patching.altitude_factor;
end
if found
    diagnostics.best_timing_estimate = candidates(1).timing;
end
end

function candidates = evaluate_altitude(problem, database, departures, height, options)
%EVALUATE_ALTITUDE Match departure replicas and Earth legs at one altitude.
%
% DESCRIPTION:
%   Sample lunar geometry freely or over the anchored encounter-epoch
%   window. Update RTH arrival targets, screen asymptotic speeds and turning
%   angles, then rank eligible departure replicas with a finite-flyby time
%   estimate before retaining the requested number of candidates.
% INPUT:
%   problem/database  Checked physical problem and canonical encounter data.
%   departures        Database row/phase/wait shortlist from seed_departures.
%   height            Earth-perigee altitude [km].
%   options           Resolved numerical settings.
% OUTPUT:
%   candidates        Ranked compact matches, or an empty structure array.
model = problem.orbit.model;
target = orb2ds.internal.target_eci(problem.target, 0);
[positions, velocities] = orb2ds.internal.rp_circle_from_vinfplus( ...
    target, model.earth_radius_km + height, model.gm_earth_km3_s2, options.patching.n_perigee);
entries = database.encounters;
rows = departures.row;
incoming_speeds = vecnorm(entries.velocity_infinity_rth_km_s(rows, :), 2, 2);
moon_minimum = model.moon_radius_km;
if isfield(problem.constraints, 'min_moon_altitude_km')
    moon_minimum = moon_minimum + problem.constraints.min_moon_altitude_km;
end
candidates = struct([]);
epoch_angles = [];
if isfield(problem.constraints, 'initial_time_days') && ~isempty(rows)
    % Sample physical encounter epochs when departure geometry is anchored.
    encounter_times = problem.constraints.initial_time_days + ...
        departures.wait_days + entries.duration_days(rows);
    earliest = min(encounter_times);
    latest = max(encounter_times) + options.patching.flyby_horizon_days;
    if ~isfield(problem.constraints, 'initial_phase')
        latest = latest + problem.constraints.max_wait_time_days;
    end
    epoch_angles = model.moon_angle_ref_rad + ...
        unique(linspace(earliest, latest, options.patching.n_moon)) / model.time_days;
end
for perigee = 1:size(positions, 1)
    earth_position = positions(perigee, :).';
    earth_post_velocity = velocities(perigee, :).';
    theta0 = mod(atan2(earth_position(2), earth_position(1)) - pi, 2 * pi);
    if theta0 > 1.5 * pi
        theta0 = theta0 - 2 * pi;
    end
    angles = theta0 - (0:options.patching.n_moon - 1) * pi / (2 * options.patching.n_moon);
    if ~isempty(epoch_angles)
        angles = epoch_angles;
    end
    for angle = angles
        radial = [cos(angle); sin(angle); 0];
        transverse = [-sin(angle); cos(angle); 0];
        moon_position = model.distance_km * radial;
        target_epoch = 0;
        if strcmp(problem.target.frame, 'earth_sun_rth')
            peri_time = (angle - model.moon_angle_ref_rad) * model.time_days;
            target_epoch = peri_time + 2;
            for iteration = 1:options.patching.target_iterations
                [earth, success] = orb2ds.internal.earth_seed_leg( ...
                    problem, height, perigee, angle, target_epoch, options);
                if ~success
                    break
                end
                updated_epoch = peri_time + earth.duration_days;
                if abs(updated_epoch - target_epoch) < 1e-8
                    break
                end
                target_epoch = updated_epoch;
            end
            if ~success
                continue
            end
            target_epoch = earth.target_epoch_days;
            duration = earth.duration_days;
            initial_velocity = earth.initial_velocity_km_s;
            arrival_velocity = earth.periapsis_velocity_pre_km_s;
            earth_position = earth.periapsis_position_km;
            earth_post_velocity = arrival_velocity + earth.delta_v_km_s;
        else
            [duration, initial_velocity, arrival_velocity, success] = ...
                orb2ds.internal.perigee_lambert(moon_position, earth_position, model, options);
            if ~success
                continue
            end
        end
        outgoing = [dot(initial_velocity, radial); ...
            dot(initial_velocity, transverse) - model.velocity_km_s; initial_velocity(3)];
        speed = norm(outgoing);
        neighbors = find(abs(incoming_speeds - speed) <= options.patching.speed_tolerance_km_s);
        if isempty(neighbors)
            continue
        end
        incoming = entries.velocity_infinity_rth_km_s(rows(neighbors), :);
        cosine = sum(incoming .* outgoing.', 2) ./ (incoming_speeds(neighbors) * speed);
        maximum_sine = 1 ./ (1 + moon_minimum * incoming_speeds(neighbors).^2 / model.gm_moon_km3_s2);
        allowed = cosine >= 1 - 2 * maximum_sine.^2;
        neighbors = neighbors(allowed);
        if isempty(neighbors)
            continue
        end
        % Estimate finite inbound flyby time before selecting a database row.
        incoming = entries.velocity_infinity_rth_km_s(rows(neighbors), :);
        speeds = incoming_speeds(neighbors);
        turn = acos(max(-1, min(1, sum(incoming .* outgoing.', 2) ./ (speeds * speed))));
        mean_speed = (speeds + speed) / 2;
        semimajor_axis_km = model.gm_moon_km3_s2 ./ mean_speed.^2;
        eccentricity = 1 ./ sin(turn / 2);
        anomaly = acosh(max(1, (1 + model.encounter_radius_km ./ ...
            semimajor_axis_km) ./ eccentricity));
        inbound = sqrt(semimajor_axis_km.^3 / model.gm_moon_km3_s2) .* ...
            (eccentricity .* sinh(anomaly) - anomaly) / 86400;
        peri_time = (angle - model.moon_angle_ref_rad) * model.time_days;
        raw_departure = peri_time - inbound - entries.duration_days(rows(neighbors));
        flight = entries.duration_days(rows(neighbors)) + inbound + duration;
        timing = orb2ds.internal.seed_timing(problem, raw_departure, ...
            departures.phase(neighbors), departures.wait_days(neighbors), flight);
        speed_error = abs(speeds - speed);
        phase_error = abs(mod(timing.phase - entries.departure_phase(rows(neighbors)) + ...
            0.5, 1) - 0.5);
        [~, order] = sortrows([timing.time_excess_days, ...
            phase_error > 1e-10, timing.moon_phase_mismatch_rad, speed_error], [1, 2, 3, 4]);
        closest = order(1);
        replica = neighbors(closest);
        row = rows(replica);
        names = fieldnames(timing);
        for index = 1:numel(names)
            timing.(names{index}) = timing.(names{index})(closest);
        end
        entry = struct('row_id', row, 'departure_phase', departures.phase(replica), ...
            'wait_days', timing.wait_days, ...
            'delta_v_km_s', entries.delta_v_km_s(row, :), ...
            'duration_days', entries.duration_days(row), ...
            'state_entry', entries.state_entry(row, :), ...
            'velocity_infinity_rth_km_s', entries.velocity_infinity_rth_km_s(row, :));
        earth = struct('initial_position_km', moon_position, 'initial_velocity_km_s', initial_velocity, ...
            'periapsis_position_km', earth_position, 'periapsis_velocity_pre_km_s', arrival_velocity, ...
            'delta_v_km_s', earth_post_velocity - arrival_velocity, ...
            'duration_days', duration, 'moon_angle_rad', angle, ...
            'outgoing_moon_asymptote_km_s', outgoing, 'target_epoch_days', target_epoch);
        candidate = struct('schema_version', 1, 'orbit', problem.orbit, ...
            'orbit_moon', entry, 'moon_earth', earth, 'timing', timing, ...
            'ranking', struct('earth_delta_v_km_s', norm(earth.delta_v_km_s), ...
            'speed_mismatch_km_s', speed_error(closest), ...
            'departure_phase_distance', phase_error(closest), 'altitude_km', height), ...
            'provenance', struct('database_row', row, 'perigee_sample', perigee, ...
            'database_departure_phase', entries.departure_phase(row), ...
            'seed_target', problem.target));
        if isempty(candidates)
            candidates = candidate;
        else
            candidates(end + 1, 1) = candidate;
        end
    end
end
if ~isempty(candidates)
    ranks = arrayfun(@rank_values, candidates, 'UniformOutput', false);
    [~, order] = sortrows(vertcat(ranks{:}), [1, 2, 3, 4]);
    candidates = candidates(order(1:min(numel(order), options.patching.n_candidates)));
end
end

function values = rank_values(candidate)
%RANK_VALUES Prefer time-compatible exact database phases, then lunar alignment.
values = [candidate.timing.time_excess_days, ...
    candidate.ranking.departure_phase_distance > 1e-10, ...
    candidate.timing.moon_phase_mismatch_rad, ...
    candidate.ranking.earth_delta_v_km_s];
end

function better = better_rank(first, second)
%BETTER_RANK Compare the same lexicographic ranking across altitude trials.
a = rank_values(first);
b = rank_values(second);
index = find(a ~= b, 1);
better = ~isempty(index) && a(index) < b(index);
end
