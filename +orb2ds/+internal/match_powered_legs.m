function [matches, evaluated] = match_powered_legs(problem, entries, departures, ...
    earth_legs, perigee_samples, height, minimum, options, cutoff)
%MATCH_POWERED_LEGS Search powered pairs using a sorted perilune-speed bound.
%
%   Bootstrap near each Earth leg's transformed speed, then search binary
%   intervals that can improve the shared shortlist at this Earth altitude.
%   The conic score uses both asymptotes in estimated common perilune axes.
%   Return compact ranked matches and the number of pairs scored.
%
%   entries/departures  Encounter catalogue and selected phase/wait replicas.
%   earth_legs         Candidate Earth arcs from one altitude [km, km/s, days].
%   perigee_samples    Perigee-circle sample for each Earth arc.
%   height/minimum     Earth altitude and minimum lunar radius [km].
%   problem/options   Checked physical problem and numerical settings.
%   cutoff            Excess time, phase indicator and weighted cost at the
%                     edge of the current shortlist across all angle bins.

matches = struct([]);
evaluated = 0;
model = problem.orbit.model;
if isempty(earth_legs) || minimum >= model.encounter_radius_km
    return
end

% Index distinct hyperbolic departures once for all Earth legs.
rows = departures.row;
incoming = entries.velocity_infinity_rth_km_s(rows, :);
speed = vecnorm(incoming, 2, 2);
escape_squared = 2 * model.gm_moon_km3_s2 / minimum;
transformed_in = sqrt(speed.^2 + escape_squared);
replicas = find(isfinite(speed) & speed > 0);
valid_rows = rows(replicas);
[~, distinct] = unique([departures.phase(replicas), departures.wait_days(replicas), ...
    entries.delta_v_km_s(valid_rows, :), entries.duration_days(valid_rows), ...
    entries.state_entry(valid_rows, :), incoming(replicas, :)], 'rows', 'stable');
replicas = replicas(distinct);
[sorted_speed, order] = sort(transformed_in(replicas));
replicas = replicas(order);
if isempty(replicas)
    return
end
outgoing = reshape([earth_legs.outgoing_moon_asymptote_km_s], 3, []).';
outgoing_speed = vecnorm(outgoing, 2, 2);
transformed_out = sqrt(outgoing_speed.^2 + escape_squared);
earth_burn = vecnorm(reshape([earth_legs.delta_v_km_s], 3, []).', 2, 2);
departure_burn = vecnorm(entries.delta_v_km_s(rows, :), 2, 2);
orbit_days = entries.duration_days(rows);
phase = departures.phase;
if isfield(problem.constraints, 'initial_phase')
    phase = mod(problem.constraints.initial_phase + ...
        departures.wait_days / problem.orbit.period_days, 1);
end
phase_error = abs(mod(phase - entries.departure_phase(rows) + 0.5, 1) - 0.5);
phase_key = phase_error > 1e-10;
best_phase = min(phase_key(replicas));
time_weight = options.patching.time_weight_m_s_day / 1000;
lunar_weight = options.patching.lunar_impulse_weight;
count = options.patching.n_candidates;
best = zeros(0, 8);
worst = cutoff;

% The neighboring speed bins make a cheap first pass for an incumbent.
nearest = zeros(numel(earth_legs), 1);
nearest_gap = zeros(size(nearest));
for leg = find(outgoing_speed > 0 & isfinite(outgoing_speed)).'
    value = transformed_out(leg);
    pos = min(numel(sorted_speed), lower_bound(sorted_speed, value));
    nearest(leg) = pos;
    neighbors = max(1, pos - 2):min(numel(sorted_speed), pos + 2);
    nearest_gap(leg) = min(abs(sorted_speed(neighbors) - value));
    evaluate(leg, replicas(neighbors));
end

% Search Earth legs nearest a departure speed first. Keep checking the
% current shortlist as new pairs tighten its cost and timing bounds.
legs = find(nearest > 0);
[~, order] = sort(nearest_gap(legs));
for leg = legs(order).'
    value = transformed_out(leg);
    first = 1;
    last = numel(sorted_speed);
    if worst(1) == 0 && worst(2) == best_phase
        % The score bounds the unweighted perilune speed difference.
        budget = (worst(3) - earth_burn(leg)) / lunar_weight;
        margin = 16 * eps(max(1, max(abs([value, budget]))));
        if budget < -margin
            continue
        end
        first = lower_bound(sorted_speed, value - budget - margin);
        last = lower_bound(sorted_speed, value + budget + margin) - 1;
    end
    interval = (first:last).';
    interval(abs(interval - nearest(leg)) <= 2) = [];
    candidates = replicas(interval);
    if isempty(candidates)
        continue
    end
    delta = vecnorm(incoming(candidates, :) - outgoing(leg, :), 2, 2);
    [~, order] = sort(delta);
    candidates = candidates(order);
    for start = 1:256:numel(candidates)
        batch = candidates(start:min(start + 255, numel(candidates)));
        evaluate(leg, batch);
    end
end

% Materialize only the retained pairs, in the order used by assembly.
for k = 1:size(best, 1)
    leg = best(k, 6);
    replica = best(k, 7);
    row = rows(replica);
    earth = earth_legs(leg);
    flight = best(k, 5);
    inbound = flight - (orbit_days(replica) + earth.duration_days);
    timing = orb2ds.internal.seed_timing(problem, perilune_epoch(leg) - inbound - ...
        orbit_days(replica), departures.phase(replica), departures.wait_days(replica), flight);
    timing.phase = departures.phase(replica);
    entry = struct('row_id', row, 'departure_phase', departures.phase(replica), ...
        'wait_days', timing.wait_days, 'delta_v_km_s', entries.delta_v_km_s(row, :), ...
        'duration_days', orbit_days(replica), 'state_entry', entries.state_entry(row, :), ...
        'velocity_infinity_rth_km_s', incoming(replica, :));
    lunar_burn = best(k, 8);
    ranking = struct('earth_delta_v_km_s', earth_burn(leg), ...
        'lunar_delta_v_km_s', lunar_burn, ...
        'total_delta_v_km_s', departure_burn(replica) + lunar_burn + earth_burn(leg), ...
        'powered_score_km_s', best(k, 3), ...
        'speed_mismatch_km_s', abs(outgoing_speed(leg) - speed(replica)), ...
        'departure_phase_distance', phase_error(replica), 'altitude_km', height);
    provenance = struct('database_row', row, 'perigee_sample', perigee_samples(leg), ...
        'database_departure_phase', entries.departure_phase(row), ...
        'seed_target', problem.target, 'patching_method', 'powered');
    match = struct('schema_version', 1, 'orbit', problem.orbit, ...
        'orbit_moon', entry, 'moon_earth', earth, 'timing', timing, ...
        'ranking', ranking, 'provenance', provenance);
    if k == 1
        matches = repmat(match, size(best, 1), 1);
    end
    matches(k) = match;
end

    function evaluate(leg, batch)
        % Respect timing and phase before applying the cost lower bound.
        flight = orbit_days(batch) + earth_legs(leg).duration_days;
        peri_time = perilune_epoch(leg);
        if isfinite(worst(1))
            optimistic = orb2ds.internal.seed_timing(problem, peri_time - orbit_days(batch), ...
                departures.phase(batch), departures.wait_days(batch), flight);
            cost_bound = departure_burn(batch) + lunar_weight * abs(transformed_in(batch) - ...
                transformed_out(leg)) + earth_burn(leg) + time_weight * flight;
            margin = 16 * eps(max(1, worst(3)));
            keep = optimistic.time_excess_days < worst(1) | ...
                (optimistic.time_excess_days == worst(1) & ...
                (phase_key(batch) < worst(2) | ...
                (phase_key(batch) == worst(2) & cost_bound <= worst(3) + margin)));
            batch = batch(keep);
            flight = flight(keep);
        end
        if isempty(batch)
            return
        end
        [lunar_burn, inbound] = score_batch(incoming(batch, :), outgoing(leg, :), ...
            speed(batch), minimum, model);
        evaluated = evaluated + numel(batch);
        flight = flight + inbound;
        timing = orb2ds.internal.seed_timing(problem, peri_time - inbound - orbit_days(batch), ...
            departures.phase(batch), departures.wait_days(batch), flight);
        cost = departure_burn(batch) + lunar_weight * lunar_burn + earth_burn(leg) + ...
            time_weight * flight;
        keys = [timing.time_excess_days, phase_key(batch), cost, ...
            timing.moon_phase_mismatch_rad, flight, repmat(leg, numel(batch), 1), batch, lunar_burn];
        best = sortrows([best; keys(isfinite(cost), :)], 1:7);
        best = best(1:min(count, size(best, 1)), :);
        if size(best, 1) == count
            local = best(end, 1:3);
            first_difference = find(local ~= worst, 1);
            if ~isempty(first_difference) && local(first_difference) < worst(first_difference)
                worst = local;
            end
        end
    end

    function time = perilune_epoch(leg)
        time = (earth_legs(leg).moon_angle_rad - model.moon_angle_ref_rad) * model.time_days;
    end
end

function index = lower_bound(sorted, value)
%LOWER_BOUND Return the first index at or above value, or numel(sorted)+1.
first = 1;
last = numel(sorted) + 1;
while first < last
    middle = floor((first + last) / 2);
    if sorted(middle) < value
        first = middle + 1;
    else
        last = middle;
    end
end
index = first;
end

function [cost, inbound] = score_batch(incoming, outgoing, speed, minimum, model)
%SCORE_BATCH Estimate rotation from entry to perilune in two conic passes.
boundary = model.encounter_radius_km;
gm = model.gm_moon_km3_s2;
inbound = boundary ./ sqrt(speed.^2 + 2 * gm / boundary) / 86400;
for iteration = 1:2
    angle = inbound / model.time_days;
    c = cos(angle);
    s = sin(angle);
    aligned = [c .* incoming(:, 1) + s .* incoming(:, 2), ...
        -s .* incoming(:, 1) + c .* incoming(:, 2), incoming(:, 3)];
    [cost, updated] = orb2ds.internal.powered_perilune( ...
        aligned, outgoing, gm, minimum, boundary, 12);
    valid = isfinite(cost);
    inbound(valid) = updated(valid);
end
end
