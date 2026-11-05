function timing = seed_timing(problem, raw_departure, phase, wait, flight)
%SEED_TIMING Anchor patch epochs and screen waits and flight/total durations.
%
% PROTOTYPE:
%   timing = orb2ds.internal.seed_timing(problem, raw_departure, phase, wait, flight)
% DESCRIPTION:
%   Keep omitted epoch/phase free. A specified epoch anchors departure after
%   waiting. If phase is free, choose the earliest nonnegative wait that
%   preserves the sampled lunar geometry; if that exceeds the wait cap,
%   choose the closer endpoint. A specified phase uses its selected orbit
%   waiting replica. No physical cap is relaxed when a seed exceeds it.
% INPUT:
%   problem        Checked physical problem.
%   raw_departure  Scalar or column of geometrically matched epochs [days].
%   phase, wait    Corresponding departure phases [-] and proposed waits [days].
%   flight         Scalar or column of flight durations [days].
% OUTPUT:
%   timing  Arrays of anchored departure_days, phase, wait_days,
%           transfer_days, total_days, time_excess_days and
%           moon_phase_mismatch_rad. Excess is zero when all caps are met.

constraints = problem.constraints;
has_epoch = isfield(constraints, 'initial_time_days');
has_phase = isfield(constraints, 'initial_phase');
wait_cap = constraints.max_wait_time_days;
if isfield(constraints, 'max_total_time_days')
    wait_cap = min(wait_cap, max(0, constraints.max_total_time_days - flight));
end

departure = raw_departure;
mismatch = zeros(size(raw_departure));
if has_epoch
    if ~has_phase
        lunar_period = 2 * pi * problem.orbit.model.time_days;
        wait = mod(raw_departure - constraints.initial_time_days, lunar_period);
        over = wait > wait_cap;
        capped = min(wait, wait_cap);
        at_zero = abs(mod((constraints.initial_time_days - raw_departure) / ...
            problem.orbit.model.time_days + pi, 2 * pi) - pi);
        at_cap = abs(mod((constraints.initial_time_days + capped - raw_departure) / ...
            problem.orbit.model.time_days + pi, 2 * pi) - pi);
        wait(over) = capped(over);
        wait(over & at_zero <= at_cap) = 0;
    end
    departure = constraints.initial_time_days + wait;
    mismatch = abs(mod((departure - raw_departure) / ...
        problem.orbit.model.time_days + pi, 2 * pi) - pi);
end
if has_phase
    phase = mod(constraints.initial_phase + wait / problem.orbit.period_days, 1);
end
total = wait + flight;
excess = zeros(size(flight));
if has_epoch || has_phase
    excess = max(excess, wait - constraints.max_wait_time_days);
end
if isfield(constraints, 'max_transfer_time_days')
    excess = max(excess, flight - constraints.max_transfer_time_days);
end
if isfield(constraints, 'max_total_time_days')
    excess = max(excess, total - constraints.max_total_time_days);
end
timing = struct('departure_days', departure, 'phase', phase, ...
    'wait_days', wait, 'transfer_days', flight, 'total_days', total, ...
    'time_excess_days', excess, 'moon_phase_mismatch_rad', mismatch);
end
