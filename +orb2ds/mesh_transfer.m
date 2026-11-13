function [seed, summary] = mesh_transfer(problem, transfer, supplied)
%MESH_TRANSFER Discretize physical arcs while preserving event anchors and jumps.
%
% PROTOTYPE:
%   seed = orb2ds.mesh_transfer(problem, transfer, options)
%   [seed, summary] = orb2ds.mesh_transfer(problem, transfer, options)
%
% DESCRIPTION:
%   Bound initial spacing globally, optionally refining one event interval.
%   Preserve physical arc endpoints and lunar periapsis. factor=1 disables
%   refinement, using the global spacing on every arc. No solver remeshing.
%
% INPUT:
%   problem   Current physical problem.
%   transfer  Compact assembled arc recipes; no database is needed.
%   options   mesh.max_step_days [days]; mesh.refinement fields from,
%             from_offset_days [days], to, factor [>=1]. See docs/MESH.md.
%             from/to select departure, moon_entry, moon_periapsis,
%             moon_exit or earth_periapsis; they are not numeric node indices.
% OUTPUT:
%   seed      Canonical schema-1 physical node record. States are post-impulse
%             rotating km/km/s, epochs local days. Patch position/velocity
%             defects remain visible to the feasibility stage. The original
%             departure and terminal impulses initialize the burn variables.
%   summary   Compact spacing, interval and per-leg counts, also retained in
%             seed.provenance.mesh. Contains no sampled histories.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
orb2ds.internal.same_orbit(problem.orbit, transfer.orbit);
model = problem.orbit.model;
refinement = options.mesh.refinement;
refinement.start_days = [];
refinement.end_days = [];
refinement.max_step_days = options.mesh.max_step_days / refinement.factor;
assert(refinement.max_step_days >= options.solver.minimum_segment_days, ...
    'orb2ds:MeshResolution', 'The requested mesh step is below solver.minimum_segment_days.');
if refinement.factor > 1
    event_times = transfer.events;
    event_times.departure_days = transfer.arcs(1).start_days;
    refinement.start_days = event_times.([refinement.from, '_days']) + ...
        refinement.from_offset_days;
    refinement.end_days = event_times.([refinement.to, '_days']);
    assert(refinement.start_days >= transfer.arcs(1).start_days && ...
        refinement.end_days <= transfer.arcs(end).end_days && ...
        refinement.start_days < refinement.end_days, 'orb2ds:MeshInterval', ...
        'The refinement interval must be nonempty and inside the assembled transfer.');
end
times = transfer.events.moon_periapsis_days;
for index = 1:numel(transfer.arcs)
    arc = transfer.arcs(index);
    boundaries = [arc.start_days; arc.end_days];
    if refinement.factor > 1
        extra = [refinement.start_days; refinement.end_days; ...
            transfer.events.moon_periapsis_days];
        boundaries = unique([boundaries; extra(extra > arc.start_days & extra < arc.end_days)]);
    end
    for interval = 1:numel(boundaries) - 1
        first = boundaries(interval);
        last = boundaries(interval + 1);
        step = options.mesh.max_step_days;
        if refinement.factor > 1 && first >= refinement.start_days && last <= refinement.end_days
            step = refinement.max_step_days;
        end
        count = max(2, ceil((last - first) / step) + 1);
        times = [times; linspace(first, last, count).'];
    end
end
times = unique(times);
assert(all(diff(times) + 64 * eps(max(abs(times))) >= options.solver.minimum_segment_days), ...
    'orb2ds:MeshResolution', ...
    'Adjacent mesh/event nodes are closer than solver.minimum_segment_days.');
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
    'wait_days', transfer.wait_days, 'transfer_days', times(end) - times(1), ...
    'total_days', transfer.wait_days + times(end) - times(1));
seed = struct('schema_version', 1, 'orbit', problem.orbit, ...
    'nodes', struct('time_days', times, 'state_post', states, ...
    'delta_v_km_s', impulses), 'events', events, 'timing', timing, ...
    'integration', options.integration, 'provenance', transfer.provenance);
% Keep construction diagnostics independent of temporary plotting samples.
summary = struct('n_nodes', numel(times), 'max_step_limit_days', options.mesh.max_step_days, ...
    'min_step_days', min(diff(times)), 'max_step_days', max(diff(times)), ...
    'refinement', refinement);
names = {'orbit_to_moon', 'moon_flyby', 'moon_to_earth'};
for index = 1:numel(transfer.arcs)
    arc = transfer.arcs(index);
    local = times(times >= arc.start_days & times <= arc.end_days);
    summary.arcs(index) = struct('name', names{index}, 'n_nodes', numel(local), ...
        'start_days', local(1), 'end_days', local(end), ...
        'min_step_days', min(diff(local)), 'max_step_days', max(diff(local)));
end
seed.provenance.mesh = summary;
seed = orb2ds.internal.check_record(seed);
if options.output.display
    fprintf('\n[Orb2DS] Shooting mesh\n\n');
    fprintf('  Total nodes                    : %d\n', summary.n_nodes);
    fprintf('  Initial step range [days]      : %.6g -- %.6g\n', summary.min_step_days, summary.max_step_days);
    if refinement.factor > 1
        fprintf('\n  Local refinement\n');
        fprintf('    Epoch interval [days]        : [%.9g, %.9g]\n', refinement.start_days, refinement.end_days);
        fprintf('    Refinement factor            : %.6g\n', refinement.factor);
        fprintf('    Maximum step [days]          : %.6g\n', refinement.max_step_days);
    end
    fprintf('\n  %-20s %8s %22s\n', 'Arc', 'Nodes', 'Maximum step [days]');
    labels = {'Orbit to Moon', 'Lunar flyby', 'Moon to Earth'};
    for index = 1:numel(summary.arcs)
        arc = summary.arcs(index);
        fprintf('  %-20s %8d %22.6g\n', labels{index}, arc.n_nodes, arc.max_step_days);
    end
end
end
