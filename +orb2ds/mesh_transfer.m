function seed = mesh_transfer(problem, transfer, supplied)
%MESH_TRANSFER Discretize physical arcs while preserving event anchors and jumps.
%
% PROTOTYPE:
%   seed = orb2ds.mesh_transfer(problem, transfer, options)
%
% INPUT:
%   problem   Current physical problem.
%   transfer  Compact assembled arc recipes; no database is needed.
%   options   Optional numerical settings; mesh.max_step_days bounds spacing.
% OUTPUT:
%   seed      Canonical schema-1 physical node record. States are post-impulse
%             rotating km/km/s, epochs local days. Patch position/velocity
%             defects remain visible to the feasibility stage. The original
%             departure and terminal impulses initialize the burn variables.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
orb2ds.internal.same_orbit(problem.orbit, transfer.orbit);
model = problem.orbit.model;
times = transfer.events.moon_periapsis_days;
for index = 1:numel(transfer.arcs)
    arc = transfer.arcs(index);
    count = max(2, ceil((arc.end_days - arc.start_days) / options.mesh.max_step_days) + 1);
    times = [times; linspace(arc.start_days, arc.end_days, count).'];
end
times = unique(times);
states = zeros(numel(times), 6);
for index = 1:numel(transfer.arcs)
    arc = transfer.arcs(index);
    selected = find(times >= arc.start_days & times <= arc.end_days);
    states(selected, :) = orb2ds.internal.evaluate_arc(arc, times(selected), model, options);
end
impulses = zeros(numel(times), 3);
impulses(1, :) = transfer.departure_impulse_km_s;

% The final arc supplies pre-burn velocity; only the final node is post-burn.
inertial = orb2ds.internal.frames(states(end, :), times(end), model, 'to_eci');
inertial(4:6) = inertial(4:6) + transfer.terminal_impulse_eci_km_s(:).';
post = orb2ds.internal.frames(inertial, times(end), model, 'to_rotating');
impulses(end, :) = post(4:6) - states(end, 4:6);
states(end, :) = post;
events = transfer.events;
[~, events.moon_periapsis_node] = min(abs(times - events.moon_periapsis_days));
[~, events.moon_entry_node] = min(abs(times - events.moon_entry_days));
[~, events.moon_exit_node] = min(abs(times - events.moon_exit_days));
events.earth_periapsis_node = numel(times);
timing = struct('departure_phase', transfer.departure_phase, ...
    'departure_time_days', times(1), 'final_time_days', times(end), ...
    'wait_days', [], 'transfer_days', times(end) - times(1), ...
    'total_days', times(end) - times(1));
seed = struct('schema_version', 1, 'orbit', problem.orbit, ...
    'nodes', struct('time_days', times, 'state_post', states, ...
    'delta_v_km_s', impulses), 'events', events, 'timing', timing, ...
    'integration', options.integration, 'provenance', transfer.provenance);
seed = orb2ds.internal.check_record(seed);
end
