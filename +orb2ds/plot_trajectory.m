function figure_handle = plot_trajectory(trajectory, settings)
%PLOT_TRAJECTORY Show a reconstructed transfer using the thesis trajectory style.
%
% PROTOTYPE:
%   figure_handle = orb2ds.plot_trajectory(trajectory, settings)
%
% DESCRIPTION:
%   Black propagated arcs and node circles, blue scaled impulse arrows,
%   initial/final markers and Times labels follow the thesis plots. Separate
%   arcs preserve shooting defects. The default is an XY view in rotating DU;
%   the ECI view uses km and includes the circular Moon path. Three-dimensional
%   data are retained in either view. Does not save or modify the input.
%
% INPUT:
%   trajectory  Output of reconstruct_trajectory; physical rotating states.
%   settings    Optional structure: visible ('on'), frame ('rotating' or
%               'eci'), view ([0, 90] azimuth/elevation in degrees),
%               show_nodes (true), show_impulses (true), impulse_scale (0.38).
%               The longest arrow spans impulse_scale times the trajectory
%               extent; arrows keep relative burn magnitudes, not length units.
% OUTPUT:
%   figure_handle  Figure with trajectory, node and impulse legend entries.

if nargin < 2
    settings = struct();
end
defaults = struct('visible', 'on', 'frame', 'rotating', 'view', [0, 90], ...
    'show_nodes', true, 'show_impulses', true, 'impulse_scale', 0.38);
settings = orb2ds.internal.merge_options(defaults, settings, 'plot');
settings.frame = validatestring(settings.frame, {'rotating', 'eci'});
validateattributes(settings.view, {'double'}, {'size', [1, 2], 'real', 'finite'});
validateattributes(settings.impulse_scale, {'double'}, {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(settings.show_nodes, {'logical'}, {'scalar'});
validateattributes(settings.show_impulses, {'logical'}, {'scalar'});
model = trajectory.model;
nodes = trajectory.nodes.state_post(:, 1:3);
impulses = trajectory.nodes.delta_v_km_s;
positions = cellfun(@(arc) arc.state(:, 1:3), trajectory.segments, 'UniformOutput', false);

% Rotate positions and free impulse vectors differently: burns have no shift.
if strcmp(settings.frame, 'eci')
    states = orb2ds.internal.frames(trajectory.nodes.state_post, ...
        trajectory.nodes.time_days, model, 'to_eci');
    nodes = states(:, 1:3);
    angle = trajectory.nodes.time_days / model.time_days + model.moon_angle_ref_rad;
    impulses = [cos(angle) .* impulses(:, 1) - sin(angle) .* impulses(:, 2), ...
        sin(angle) .* impulses(:, 1) + cos(angle) .* impulses(:, 2), impulses(:, 3)];
    for index = 1:numel(positions)
        arc = trajectory.segments{index};
        states = orb2ds.internal.frames(arc.state, arc.time_days, model, 'to_eci');
        positions{index} = states(:, 1:3);
    end
    length_unit = 1;
    units = 'km';
    frame_name = 'Earth-centered inertial frame';
else
    length_unit = model.distance_km;
    units = 'DU';
    frame_name = 'Earth-Moon barycentric rotating frame';
end
nodes = nodes / length_unit;
positions = cellfun(@(points) points / length_unit, positions, 'UniformOutput', false);
points = vertcat(positions{:});

figure_handle = figure('Name', 'orb2ds transfer', 'Visible', settings.visible, ...
    'Color', 'w', 'Theme', 'light');
axes_handle = axes('Parent', figure_handle, 'DataAspectRatio', [1, 1, 1], ...
    'View', settings.view, 'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', ...
    'Box', 'on', 'FontName', 'Times New Roman', 'FontSize', 15, ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k');
hold(axes_handle, 'on');
for index = 1:numel(positions)
    position = positions{index};
    line_handle = plot3(axes_handle, position(:, 1), position(:, 2), position(:, 3), ...
        'k-', 'LineWidth', 1.2, 'DisplayName', 'Transfer');
    if index > 1
        line_handle.HandleVisibility = 'off';
    end
end
if settings.show_nodes
    plot3(axes_handle, nodes(:, 1), nodes(:, 2), nodes(:, 3), 'ko', ...
        'MarkerSize', 6, 'DisplayName', 'Shooting nodes');
end
plot3(axes_handle, nodes(1, 1), nodes(1, 2), nodes(1, 3), 'bo', ...
    'MarkerSize', 9, 'LineWidth', 2, 'DisplayName', 'Departure');
plot3(axes_handle, nodes(end, 1), nodes(end, 2), nodes(end, 3), 'ro', ...
    'MarkerSize', 9, 'LineWidth', 2, 'DisplayName', 'Arrival');

% Keep physical body locations and the inertial Moon path in the viewport.
if strcmp(settings.frame, 'eci')
    angle = linspace(0, 2 * pi, 200).';
    moon_path = model.distance_km * [cos(angle), sin(angle), zeros(size(angle))];
    plot3(axes_handle, moon_path(:, 1), moon_path(:, 2), moon_path(:, 3), '--', ...
        'Color', [0.6, 0.6, 0.6], 'DisplayName', 'Moon path');
    plot3(axes_handle, 0, 0, 0, 'bo', 'MarkerFaceColor', 'b', 'DisplayName', 'Earth');
    bounds = [points; nodes; moon_path; 0, 0, 0];
else
    earth = [-model.mu, 0, 0];
    moon = [1 - model.mu, 0, 0];
    plot3(axes_handle, earth(1), 0, 0, 'bo', 'MarkerFaceColor', 'b', 'DisplayName', 'Earth');
    plot3(axes_handle, moon(1), 0, 0, 'ko', 'MarkerFaceColor', 'k', 'DisplayName', 'Moon');
    bounds = [points; nodes; earth; moon];
end

% Scale arrows uniformly and suppress negligible burns, as in the thesis plots.
strength = vecnorm(impulses, 2, 2);
if settings.show_impulses && settings.impulse_scale > 0 && max(strength) > 0
    active = strength > 1e-4 * max(strength);
    span = max(max(points, [], 1) - min(points, [], 1));
    arrows = settings.impulse_scale * span * impulses(active, :) / max(strength);
    quiver3(axes_handle, nodes(active, 1), nodes(active, 2), nodes(active, 3), ...
        arrows(:, 1), arrows(:, 2), arrows(:, 3), 0, 'Color', 'b', ...
        'LineWidth', 0.8, 'DisplayName', '$\Delta V$ impulses (scaled)');
    bounds = [bounds; nodes(active, :) + arrows];
end

% Compute equal XY limits from data, avoiding renderer-dependent limit queries.
lower = min(bounds, [], 1);
upper = max(bounds, [], 1);
center = (lower + upper) / 2;
half_span = 0.55 * max([upper(1:2) - lower(1:2), eps]);
axes_handle.XLim = center(1) + half_span * [-1, 1];
axes_handle.YLim = center(2) + half_span * [-1, 1];
xlabel(axes_handle, ['x [', units, ']'], 'Interpreter', 'latex');
ylabel(axes_handle, ['y [', units, ']'], 'Interpreter', 'latex');
zlabel(axes_handle, ['z [', units, ']'], 'Interpreter', 'latex');
title(axes_handle, frame_name, 'Interpreter', 'latex');
legend(axes_handle, 'show', 'Location', 'northeastoutside', 'Interpreter', 'latex');
end
