function database = build_orbit_moon_database(orbit, filename, supplied)
%BUILD_ORBIT_MOON_DATABASE Generate reusable lunar entries or reuse a matching file.
%
% PROTOTYPE:
%   database = orb2ds.build_orbit_moon_database(orbit, filename, options)
%
% DESCRIPTION:
%   Propagate a grid of impulsive departures from a periodic spatial CR3BP
%   orbit. Retain every inward encounter before the search horizon or a body
%   impact. This extracts the thesis generator's phase/impulse grid and event
%   calculation, using the canonical model throughout. Local SOI velocities
%   and Kepler incoming asymptotes are stored with different definitions.
%   A same-name archive is reused only when orbit, grid and integration
%   settings match. Existing files are never overwritten.
%
% INPUT:
%   orbit     Complete physical orbit descriptor.
%   filename  Explicit MAT destination, in an existing directory.
%   options   Optional numerical settings; database block defines the grid.
% OUTPUT:
%   database  Canonical compact encounter database, also saved to filename.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
orbit = orb2ds.internal.check_orbit(orbit);
generation = struct('grid', options.database, 'integration', options.integration);
if isfile(filename)
    database = orb2ds.load_orbit_moon_database(filename);
    orb2ds.internal.same_orbit(database.orbit, orbit);
    assert(isequaln(database.generation, generation), 'orb2ds:DatabaseSettings', ...
        'Existing database grid or integration settings differ; choose a new filename.');
    return
end
model = orbit.model;
grid = options.database;
validateattributes(grid.phases, {'double'}, {'vector', 'real', 'finite', '>=', 0, '<=', 1});
validateattributes(grid.impulses_m_s, {'double'}, {'vector', 'real', 'finite', 'nonnegative'});
validateattributes(grid.azimuths_rad, {'double'}, {'vector', 'real', 'finite'});
validateattributes(grid.elevations_rad, {'double'}, {'vector', 'real', 'finite'});
validateattributes(grid.horizon_days, {'double'}, {'scalar', 'positive', 'finite'});
scales = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
reference = orbit.state_ref ./ scales;

% A periodic phase descriptor must close under the same model used by the grid.
closed = orb2ds.internal.propagate(reference, [0, orbit.period_days / model.time_days], ...
    model, options);
assert(norm((closed(1:3) - reference(1:3)) * model.distance_km) <= ...
    options.validation.orbit_closure_position_km && ...
    norm((closed(4:6) - reference(4:6)) * model.velocity_km_s) <= ...
    options.validation.orbit_closure_velocity_km_s, 'orb2ds:OrbitClosure', ...
    'The declared orbit does not close under its model and period.');

[magnitude, azimuth, elevation] = ndgrid(grid.impulses_m_s / 1000, ...
    grid.azimuths_rad, grid.elevations_rad);
impulses = [magnitude(:) .* cos(azimuth(:)) .* cos(elevation(:)), ...
    magnitude(:) .* sin(azimuth(:)) .* cos(elevation(:)), ...
    magnitude(:) .* sin(elevation(:))];
rows = cell(numel(grid.phases) * size(impulses, 1), 1);
task = 0;
ode_options = odeset('RelTol', options.integration.relative_tolerance, ...
    'AbsTol', options.integration.absolute_tolerance, ...
    'Events', @(t, state) encounter_events(t, state, model));
horizon = grid.horizon_days / model.time_days;
for phase = mod(grid.phases(:).', 1)
    departure = orb2ds.internal.propagate(reference, ...
        [0, phase * orbit.period_days / model.time_days], model, options);
    for impulse_index = 1:size(impulses, 1)
        task = task + 1;
        initial = departure;
        initial(4:6) = initial(4:6) + impulses(impulse_index, :).'/model.velocity_km_s;
        solution = ode113(@(t, state) orb2ds.internal.rhs_CR3BP_3D(t, state, model.mu), ...
            [0, horizon], initial, ode_options);
        terminated = isfield(solution, 'ie') && ~isempty(solution.ie) && ...
            any(solution.ie(end) == [2, 3]);
        assert(solution.x(end) == horizon || terminated, 'orb2ds:Integration', ...
            'A departure integration stopped before its horizon without a terminal event.');
        if ~isfield(solution, 'ie')
            rows{task} = zeros(0, 17);
            continue
        end
        hits = find(solution.ie == 1 & solution.xe > 0);
        count = numel(hits);
        states = solution.ye(:, hits).' .* scales.';
        [local, asymptote] = orb2ds.internal.moon_asymptote(states, model);
        rows{task} = [repmat(phase, count, 1), ...
            repmat(impulses(impulse_index, :), count, 1), ...
            solution.xe(hits).' * model.time_days, states, local, asymptote];
    end
    if options.output.display
        fprintf('orb2ds database: %d/%d departures\n', task, numel(rows));
    end
end
rows = vertcat(rows{:});
database.schema_version = 1;
database.orbit = orbit;
database.encounters = struct('row_id', (1:size(rows, 1)).', ...
    'departure_phase', rows(:, 1), 'delta_v_km_s', rows(:, 2:4), ...
    'duration_days', rows(:, 5), 'state_entry', rows(:, 6:11), ...
    'velocity_local_rth_km_s', rows(:, 12:14), ...
    'velocity_infinity_rth_km_s', rows(:, 15:17));
database.definition = struct('boundary', 'moon_radius_plus_laplace_soi', ...
    'local_velocity', 'moon_relative_inertial_in_rth', ...
    'asymptotic_velocity', 'inbound_kepler_asymptote');
database.generation = generation;
database.provenance = struct('library_version', '0.1.0-dev', ...
    'algorithm', 'thesis phase/impulse grid, canonical spatial CR3BP');
database = orb2ds.internal.check_database(database);
save(filename, 'database', '-v7.3');
end

function [value, terminal, direction] = encounter_events(~, state, model)
%ENCOUNTER_EVENTS Retain lunar inward crossings; stop at Earth or Moon impact.
earth = norm(state(1:3) + [model.mu; 0; 0]) * model.distance_km;
moon = norm(state(1:3) - [1 - model.mu; 0; 0]) * model.distance_km;
value = [moon - model.encounter_radius_km; earth - model.earth_radius_km; ...
    moon - model.moon_radius_km];
terminal = [0; 1; 1];
direction = [-1; -1; -1];
end
