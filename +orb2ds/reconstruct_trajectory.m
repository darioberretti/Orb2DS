function trajectory = reconstruct_trajectory(solution, settings)
%RECONSTRUCT_TRAJECTORY Repropagate independent shooting arcs without hiding jumps.
%
% PROTOTYPE:
%   trajectory = orb2ds.reconstruct_trajectory(solution, settings)
%
% DESCRIPTION:
%   Start every segment from its stored post-impulse state. Retain the
%   propagated pre-impulse endpoint and the next stored post-impulse node as
%   separate values. A failed candidate is also reconstructible. No data
%   are added to the solution, and no files are saved.
%
% INPUT:
%   solution  Self-contained compact physical node record.
%   settings  Optional samples_per_segment (default 50).
% OUTPUT:
%   trajectory  Separate transient object with segments, nodes, epochs,
%               physical rotating states and endpoint defects. Units km,
%               km/s and days. See docs/CONTRACTS.md.

if nargin < 2
    settings = struct();
end
settings = orb2ds.internal.merge_options(struct('samples_per_segment', 50), ...
    settings, 'reconstruction');
validateattributes(settings.samples_per_segment, {'double'}, ...
    {'scalar', 'integer', '>=', 2});
solution = orb2ds.internal.check_record(solution);
model = solution.orbit.model;
scales = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
options = orb2ds.internal.options(struct('integration', solution.integration));
trajectory.model = model;
trajectory.nodes = solution.nodes;
trajectory.events = solution.events;
trajectory.segments = cell(numel(solution.nodes.time_days) - 1, 1);
trajectory.defects = zeros(numel(trajectory.segments), 6);
for index = 1:numel(trajectory.segments)
    times = linspace(solution.nodes.time_days(index), ...
        solution.nodes.time_days(index + 1), settings.samples_per_segment).';
    initial = solution.nodes.state_post(index, :) ./ scales;
    ode_options = odeset('RelTol', options.integration.relative_tolerance, ...
        'AbsTol', options.integration.absolute_tolerance);
    [tu, history] = ode113(@(t, x) orb2ds.internal.rhs_CR3BP_3D(t, x, model.mu), ...
        times / model.time_days, initial(:), ode_options);
    states = history .* scales;
    segment = struct('time_days', tu * model.time_days, 'state', states);
    expected_pre = solution.nodes.state_post(index + 1, :);
    expected_pre(4:6) = expected_pre(4:6) - solution.nodes.delta_v_km_s(index + 1, :);
    trajectory.defects(index, :) = states(end, :) - expected_pre;
    trajectory.segments{index} = segment;
end
end
