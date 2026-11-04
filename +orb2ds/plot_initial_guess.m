function figure_handle = plot_initial_guess(transfer, seed, settings)
%PLOT_INITIAL_GUESS Sample the assembled physical legs and optionally overlay mesh nodes.
%
% PROTOTYPE:
%   figure_handle = orb2ds.plot_initial_guess(transfer)
%   figure_handle = orb2ds.plot_initial_guess(transfer, seed, settings)
%
% DESCRIPTION:
%   Plot the orbit-Moon, lunar-flyby and Moon-Earth recipes in distinct colors,
%   using their original CR3BP/two-body models. An optional compact seed adds
%   the shooting nodes and a marker at the initial refinement boundary.
%   Temporary samples are neither saved nor added to transfer/seed/results.
%
% INPUT:
%   transfer  Compact assembled transfer from assemble_transfer.
%   seed      Optional mesh_transfer output, or [] for no mesh overlay.
%   settings  plot_trajectory settings plus samples_per_arc (default 200).
%             Rotating DU or ECI km; query times are local days.
% OUTPUT:
%   figure_handle  Assembled-initial-guess figure; no feasibility claim.

if nargin < 2
    seed = [];
end
if nargin < 3
    settings = struct();
end
samples = 200;
if isfield(settings, 'samples_per_arc')
    samples = settings.samples_per_arc;
    settings = rmfield(settings, 'samples_per_arc');
end
validateattributes(samples, {'double'}, {'scalar', 'integer', '>=', 2});
model = transfer.orbit.model;
options = orb2ds.internal.options(struct('integration', transfer.integration));
trajectory = struct('model', model, 'events', transfer.events);
labels = {'Orbit-Moon leg', 'Lunar flyby', 'Moon-Earth leg'};
colors = [0, 0.447, 0.741; 0.466, 0.674, 0.188; 0.85, 0.325, 0.098];
for index = 1:numel(transfer.arcs)
    arc = transfer.arcs(index);
    times = linspace(arc.start_days, arc.end_days, samples).';
    states = orb2ds.internal.evaluate_arc(arc, times, model, options);
    trajectory.segments{index, 1} = struct('time_days', times, 'state', states, ...
        'label', labels{index}, 'color', colors(index, :));
end

% Without a mesh, retain only physical endpoints for markers and burn arrows.
if isempty(seed)
    times = [transfer.arcs(1).start_days; transfer.arcs(end).end_days];
    states = [trajectory.segments{1}.state(1, :); trajectory.segments{end}.state(end, :)];
    inertial = orb2ds.internal.frames(states(end, :), times(end), model, 'to_eci');
    inertial(4:6) = inertial(4:6) + transfer.terminal_impulse_eci_km_s(:).';
    post = orb2ds.internal.frames(inertial, times(end), model, 'to_rotating');
    burns = [transfer.departure_impulse_km_s(:).'; post(4:6) - states(end, 4:6)];
    states(end, :) = post;
    trajectory.nodes = struct('time_days', times, 'state_post', states, 'delta_v_km_s', burns);
    settings.show_nodes = false;
else
    seed = orb2ds.internal.check_record(seed);
    orb2ds.internal.same_orbit(transfer.orbit, seed.orbit);
    assert(abs(seed.nodes.time_days(1) - transfer.arcs(1).start_days) < 1e-10 && ...
        abs(seed.nodes.time_days(end) - transfer.arcs(end).end_days) < 1e-10, ...
        'orb2ds:PlotMesh', 'The mesh and assembled transfer must share their time interval.');
    trajectory.nodes = seed.nodes;
    if isfield(seed.provenance, 'mesh') && seed.provenance.mesh.refinement.factor > 1
        time = seed.provenance.mesh.refinement.start_days;
        node = find(seed.nodes.time_days == time, 1);
        trajectory.refinement_start = struct('time_days', time, ...
            'state', seed.nodes.state_post(node, :));
    end
end
figure_handle = orb2ds.plot_trajectory(trajectory, settings);
figure_handle.Name = 'Assembled initial guess';
if ~isempty(seed)
    figure_handle.Name = 'Assembled initial guess and mesh';
end
title(figure_handle.CurrentAxes, ...
    {'Assembled initial guess', figure_handle.CurrentAxes.Title.String}, 'Interpreter', 'latex');
end
