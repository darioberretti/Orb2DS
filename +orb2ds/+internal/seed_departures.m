function departures = seed_departures(problem, entries)
%SEED_DEPARTURES Shortlist database phases and admissible waiting replicas.
%
% PROTOTYPE:
%   departures = orb2ds.internal.seed_departures(problem, entries)
% DESCRIPTION:
%   Include the two closest circular phase slices for immediate departure
%   when a phase is specified. Their burn/duration data approximate that
%   exact phase. Also include database phases reachable by waiting. With a
%   specified epoch, search additional full orbit revolutions within
%   max_wait_time_days. A free epoch needs only the earliest wait for each
%   phase because its geometry remains independent.
% INPUT:
%   problem  Checked physical problem; phases normalized, times in days.
%   entries  Canonical database encounter arrays.
% OUTPUT:
%   departures  Equal-length row, phase and wait_days arrays. row indexes
%               the original database; phase is the actual seed departure.

rows = (1:numel(entries.departure_phase)).';
phases = entries.departure_phase(:);
departures = struct('row', rows, 'phase', phases, 'wait_days', zeros(size(rows)));
constraints = problem.constraints;
if ~isfield(constraints, 'initial_phase') || isempty(rows)
    return
end

phase = constraints.initial_phase;
period = problem.orbit.period_days;
grid = unique(phases);
distance = abs(mod(grid - phase + 0.5, 1) - 0.5);
[~, order] = sortrows([distance, grid], [1, 2]);
nearest = grid(order(1:min(2, numel(grid))));
immediate = find(ismember(phases, nearest));
departures.row = immediate;
departures.phase = repmat(phase, size(immediate));
departures.wait_days = zeros(size(immediate));

wait_cap = constraints.max_wait_time_days;
if wait_cap == 0
    return
end

first_wait = mod(phases - phase, 1) * period;
last_revolution = 0;
if isfield(constraints, 'initial_time_days')
    last_revolution = floor(wait_cap / period);
end
for revolution = 0:last_revolution
    waits = first_wait + revolution * period;
    keep = waits > 64 * eps(period) & waits <= wait_cap;
    departures.row = [departures.row; rows(keep)];
    departures.phase = [departures.phase; phases(keep)];
    departures.wait_days = [departures.wait_days; waits(keep)];
end
end
