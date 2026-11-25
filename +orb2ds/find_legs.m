function [candidates, diagnostics] = find_legs(problem, supplied)
%FIND_LEGS Match reusable orbit-Moon encounters to target-dependent Earth legs.
%
% PROTOTYPE:
%   [candidates, diagnostics] = orb2ds.find_legs(problem, options)
%
% DESCRIPTION:
%   Search Earth-perigee altitudes, construct tangent Lambert legs, screen
%   lunar speed/turning angles.
%   Shortlist departure phases and expand allowed orbit-wait replicas. With
%   a specified epoch, group both legs by lunar geometry before matching.
%   Powered matching compares the sum of the estimated burns, with an
%   optional flight-duration cost. Natural matching ranks viable flybys by
%   timing and estimated Earth burn.
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
%                Powered searches include pairs evaluated at each altitude.
%                Empty candidates means no seed found in this search.

if nargin < 2
    supplied = struct();
end
problem = orb2ds.internal.check_problem(problem);
options = orb2ds.internal.options(supplied, problem.constraints);
powered = strcmp(options.patching.lunar_flyby_matching_policy, 'powered');
if powered
    assert(~isfield(problem.constraints, 'impulse_nodes') || ...
        ~strcmp(problem.constraints.impulse_nodes, 'endpoints'), ...
        'orb2ds:PoweredFlyby', 'Powered patching requires an impulse at lunar perilune.');
end
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
if options.output.display
    fprintf('\n[Orb2DS] Leg matching\n\n');
    fprintf('  Lunar flyby matching policy    : %s\n', ...
        options.patching.lunar_flyby_matching_policy);
    fprintf('  Database encounters            : %d\n', diagnostics.database_rows);
end
if ~any(all(isfinite(database.encounters.velocity_infinity_rth_km_s), 2))
    diagnostics.reason = 'no_hyperbolic_encounters_in_database';
    if options.output.display
        fprintf('  No hyperbolic lunar encounters in the supplied database.\n');
    end
    return
end
found = false;
departures = orb2ds.internal.seed_departures(problem, database.encounters);
diagnostics.departure_row_count = numel(unique(departures.row));
diagnostics.departure_phase_grid = unique(database.encounters.departure_phase(departures.row));
diagnostics.departure_replicas = numel(departures.row);
if options.output.display
    fprintf('  Shortlisted encounter rows     : %d\n', diagnostics.departure_row_count);
    fprintf('  Departure / wait replicas      : %d\n', diagnostics.departure_replicas);
    fprintf('\n  %-22s %18s\n', 'Earth altitude [km]', 'Candidates found');
end
for trial = 1:options.patching.max_altitude_trials
    [at_height, pairs_evaluated] = evaluate_altitude(problem, database, departures, height, options);
    diagnostics.altitudes_km(end + 1, 1) = height;
    diagnostics.candidate_counts(end + 1, 1) = numel(at_height);
    if powered
        diagnostics.powered_pairs_evaluated(trial, 1) = pairs_evaluated;
    end
    if options.output.display
        fprintf('  %22.3f %18d\n', height, numel(at_height));
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

function [candidates, pairs_evaluated] = evaluate_altitude(problem, database, departures, height, options)
%EVALUATE_ALTITUDE Match departure replicas and Earth legs at one altitude.
%
% DESCRIPTION:
%   Build the Earth legs and lunar geometry batches before screening speeds
%   and turning angles. Retain the best matches across the batches.
% INPUT:
%   problem/database  Checked physical problem and canonical encounter data.
%   departures        Database row/phase/wait shortlist from seed_departures.
%   height            Earth-perigee altitude [km].
%   options           Resolved numerical settings.
% OUTPUT:
%   candidates        Ranked compact matches, or an empty structure array.
%   pairs_evaluated   Number of pairs scored by the powered conic model.
model = problem.orbit.model;
target = orb2ds.internal.target_eci(problem.target, 0);
[circle.positions, circle.velocities] = orb2ds.internal.rp_circle_from_vinfplus( ...
    target, model.earth_radius_km + height, model.gm_earth_km3_s2, options.patching.n_perigee);
entries = database.encounters;
rows = departures.row;
moon_minimum = model.moon_radius_km;
if isfield(problem.constraints, 'min_moon_altitude_km')
    moon_minimum = moon_minimum + problem.constraints.min_moon_altitude_km;
end
candidates = struct([]);
pairs_evaluated = 0;
powered = strcmp(options.patching.lunar_flyby_matching_policy, 'powered');
earth_legs = cell(options.patching.n_moon * size(circle.positions, 1), 1);
perigee_samples = zeros(size(earth_legs));
leg_count = 0;
epoch_angles = [];
is_rth = strcmp(problem.target.frame, 'earth_sun_rth');
if is_rth && isfield(problem.constraints, 'initial_time_days') && ~isempty(rows)
    % Absolute epochs set the target direction for the RTH Lambert legs.
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
for perigee = 1:size(circle.positions, 1)
    earth_position = circle.positions(perigee, :).';
    theta0 = mod(atan2(earth_position(2), earth_position(1)) - pi, 2 * pi);
    if theta0 > 1.5 * pi
        theta0 = theta0 - 2 * pi;
    end
    angles = theta0 - (0:options.patching.n_moon - 1) * pi / (2 * options.patching.n_moon);
    if ~isempty(epoch_angles)
        angles = epoch_angles;
    end
    for angle = angles
        if is_rth
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
        else
            [earth, success] = orb2ds.internal.earth_seed_leg( ...
                problem, height, perigee, angle, 0, options, circle);
        end
        if ~success
            continue
        end
        leg_count = leg_count + 1;
        earth_legs{leg_count} = earth;
        perigee_samples(leg_count) = perigee;
    end
end
if leg_count == 0
    return
end
earth_legs = vertcat(earth_legs{1:leg_count});
perigee_samples = perigee_samples(1:leg_count);

% Match only legs that share an encounter geometry batch.
[earth_batch, first, last] = orb2ds.internal.encounter_batches(problem, ...
    departures, entries.duration_days(rows), [earth_legs.moon_angle_rad]);
count = max(earth_batch);
earth_groups = accumarray(earth_batch, (1:leg_count).', [count, 1], @(i) {sort(i)});
single_batch = isequal(first, last);
if single_batch
    departure_groups = accumarray(first, (1:numel(rows)).', [count, 1], @(i) {sort(i)});
end
matches = cell(count, 1);
powered_best = struct([]);
cutoff = [Inf, Inf, Inf];
for batch = 1:count
    if single_batch
        members = departure_groups{batch};
    else
        members = find((first <= batch & batch <= last) | batch + count <= last);
    end
    if isempty(members)
        continue
    end
    group = struct('row', rows(members), 'phase', departures.phase(members), ...
        'wait_days', departures.wait_days(members));
    legs = earth_groups{batch};
    if powered
        [local, evaluated] = orb2ds.internal.match_powered_legs(problem, ...
            entries, group, earth_legs(legs), perigee_samples(legs), height, moon_minimum, options, cutoff);
        pairs_evaluated = pairs_evaluated + evaluated;
        if isempty(powered_best)
            powered_best = local;
        elseif ~isempty(local)
            powered_best = retain_ranked([powered_best(:); local(:)], options.patching.n_candidates);
        end
        if numel(powered_best) == options.patching.n_candidates
            worst = rank_values(powered_best(end));
            cutoff = worst(1:3);
        end
    else
        matches{batch} = match_ballistic_legs(problem, entries, group, ...
            earth_legs(legs), perigee_samples(legs), height, moon_minimum, options);
    end
end
if powered
    candidates = powered_best;
    return
end
matches = matches(~cellfun(@isempty, matches));
if ~isempty(matches)
    candidates = retain_ranked(vertcat(matches{:}), options.patching.n_candidates);
end
end

function candidates = match_ballistic_legs(problem, entries, departures, ...
    earth_legs, perigee_samples, height, moon_minimum, options)
%MATCH_BALLISTIC_LEGS Screen and rank one batch of epoch-compatible legs.
model = problem.orbit.model;
rows = departures.row;
incoming_speeds = vecnorm(entries.velocity_infinity_rth_km_s(rows, :), 2, 2);
candidates = struct([]);
for leg = 1:numel(earth_legs)
    earth = earth_legs(leg);
    outgoing = earth.outgoing_moon_asymptote_km_s;
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
    peri_time = (earth.moon_angle_rad - model.moon_angle_ref_rad) * model.time_days;
    raw_departure = peri_time - inbound - entries.duration_days(rows(neighbors));
    flight = entries.duration_days(rows(neighbors)) + inbound + earth.duration_days;
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
    timing.phase = departures.phase(replica);
    entry = struct('row_id', row, 'departure_phase', departures.phase(replica), ...
        'wait_days', timing.wait_days, ...
        'delta_v_km_s', entries.delta_v_km_s(row, :), ...
        'duration_days', entries.duration_days(row), ...
        'state_entry', entries.state_entry(row, :), ...
        'velocity_infinity_rth_km_s', entries.velocity_infinity_rth_km_s(row, :));
    candidate = struct('schema_version', 1, 'orbit', problem.orbit, ...
        'orbit_moon', entry, 'moon_earth', earth, 'timing', timing, ...
        'ranking', struct('earth_delta_v_km_s', norm(earth.delta_v_km_s), ...
        'speed_mismatch_km_s', speed_error(closest), ...
        'departure_phase_distance', phase_error(closest), 'altitude_km', height), ...
        'provenance', struct('database_row', row, 'perigee_sample', perigee_samples(leg), ...
        'database_departure_phase', entries.departure_phase(row), ...
        'seed_target', problem.target, 'patching_method', 'natural'));
    if isempty(candidates)
        candidates = candidate;
    else
        candidates(end + 1, 1) = candidate;
    end
end
end

function candidates = retain_ranked(candidates, count)
%RETAIN_RANKED Keep the best compact candidates in lexicographic order.
if isempty(candidates)
    return
end
ranks = arrayfun(@rank_values, candidates, 'UniformOutput', false);
[~, order] = sortrows(vertcat(ranks{:}));
candidates = candidates(order(1:min(numel(order), count)));
end

function values = rank_values(candidate)
%RANK_VALUES Prefer time-compatible exact database phases, then lunar alignment.
if strcmp(candidate.provenance.patching_method, 'powered')
    values = orb2ds.internal.powered_rank_keys(candidate.timing, ...
        candidate.ranking.departure_phase_distance, candidate.ranking.powered_score_km_s);
    return
end
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
