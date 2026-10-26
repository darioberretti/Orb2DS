function nlp = build_nlp(problem, seed, options)
%BUILD_NLP Form the normalized spatial multiple-shooting NLP from a compact guess.
%
% PROTOTYPE:
%   nlp = orb2ds.internal.build_nlp(problem, seed, options)
%
% DESCRIPTION:
%   Node states are post-impulse. Each impulse uses the thesis quadratic map.
%   Durations, departure epoch, normalized phase and waiting are represented
%   only where independent under the supplied initial-event information.
%   All omitted physical limits remain absent; mesh construction is separate.
%
% INPUT:
%   problem  Current canonical orbit, target and physical constraints.
%   seed     Compact schema-1 record in km, km/s and days.
%   options  Fully resolved numerical options.
% OUTPUT:
%   nlp      Runtime normalized layout, initial vector, bounds, independent
%            timing indices and shared context. Not a persistent result.

problem = orb2ds.internal.check_problem(problem);
seed = orb2ds.internal.check_record(seed);
orb2ds.internal.same_orbit(problem.orbit, seed.orbit);
nlp.problem = problem;
if isfield(nlp.problem, 'database')
    nlp.problem = rmfield(nlp.problem, 'database');
end
nlp.model = problem.orbit.model;
nlp.options = options;
nlp.seed = seed;
nlp.period_tu = problem.orbit.period_days / nlp.model.time_days;
nlp.n_nodes = numel(seed.nodes.time_days);
count = nlp.n_nodes;
assert(isfield(seed.events, 'moon_periapsis_node'), 'orb2ds:Events', ...
    'The guess requires its lunar-periapsis node association.');
nlp.moon_node = seed.events.moon_periapsis_node;
validateattributes(nlp.moon_node, {'double'}, {'integer', 'scalar', '>', 1, '<', count});
scales = [repmat(nlp.model.distance_km, 1, 3), repmat(nlp.model.velocity_km_s, 1, 3)];
[regularized, nlp.swapped] = orb2ds.internal.regularize_impulses( ...
    seed.nodes.delta_v_km_s / nlp.model.velocity_km_s);
blocks = [seed.nodes.state_post ./ scales, regularized];
nlp.initial = reshape(blocks.', [], 1);
nlp.duration_indices = 9 * count + (1:count - 1);
nlp.initial(nlp.duration_indices, 1) = diff(seed.nodes.time_days) / nlp.model.time_days;
constraints = problem.constraints;
nlp.epoch_index = [];
nlp.phase_index = [];
nlp.wait_index = [];
if ~isfield(constraints, 'initial_time_days')
    nlp.epoch_index = numel(nlp.initial) + 1;
    nlp.initial(end + 1, 1) = seed.nodes.time_days(1) / nlp.model.time_days;
end
if ~isfield(constraints, 'initial_phase')
    nlp.phase_index = numel(nlp.initial) + 1;
    nlp.initial(end + 1, 1) = seed.timing.departure_phase;
end
if isfield(constraints, 'initial_time_days') || isfield(constraints, 'initial_phase')
    nlp.wait_index = numel(nlp.initial) + 1;
    nlp.initial(end + 1, 1) = 0;
    if isfield(seed.timing, 'wait_days') && ~isempty(seed.timing.wait_days) && ...
            isfinite(seed.timing.wait_days)
        nlp.initial(end) = max(0, seed.timing.wait_days / nlp.model.time_days);
    end
end
nlp.n_variables = numel(nlp.initial);
nlp.lower = -inf(nlp.n_variables, 1);
nlp.upper = inf(nlp.n_variables, 1);
% Prevent collapsed epochs below the declared numerical mesh resolution.
nlp.lower(nlp.duration_indices) = options.solver.minimum_segment_days / nlp.model.time_days;
if ~isempty(nlp.phase_index)
    nlp.lower(nlp.phase_index) = 0;
    nlp.upper(nlp.phase_index) = 1;
end
if ~isempty(nlp.wait_index)
    nlp.lower(nlp.wait_index) = 0;
    if isfield(constraints, 'max_wait_time_days')
        nlp.upper(nlp.wait_index) = constraints.max_wait_time_days / nlp.model.time_days;
    end
end
nlp.active_impulses = true(count, 1);
if isfield(constraints, 'impulse_nodes') && strcmp(constraints.impulse_nodes, 'endpoints')
    nlp.active_impulses(2:end - 1) = false;
    for index = 2:count - 1
        indices = 9 * (index - 1) + (7:9);
        nlp.lower(indices) = 0;
        nlp.upper(indices) = 0;
        nlp.initial(indices) = 0;
    end
end
nlp.initial = max(nlp.lower, min(nlp.upper, nlp.initial));

% Physical duration caps are linear in the independent propagation times.
nlp.A = zeros(0, nlp.n_variables);
nlp.b = zeros(0, 1);
for name = {'max_transfer_time_days', 'max_total_time_days'}
    if isfield(constraints, name{1})
        row = zeros(1, nlp.n_variables);
        row(nlp.duration_indices) = 1;
        if strcmp(name{1}, 'max_total_time_days') && ~isempty(nlp.wait_index)
            row(nlp.wait_index) = 1;
        end
        existing = find(all(nlp.A == row, 2), 1);
        bound = constraints.(name{1}) / nlp.model.time_days;
        if isempty(existing)
            nlp.A(end + 1, :) = row;
            nlp.b(end + 1, 1) = bound;
        else
            nlp.b(existing) = min(nlp.b(existing), bound);
        end
        assert(constraints.(name{1}) >= (count - 1) * options.solver.minimum_segment_days, ...
            'orb2ds:MeshDuration', ...
            'The duration cap is below the mesh time resolution; reduce the mesh or minimum_segment_days.');
    end
end
earth_margin = 0;
moon_margin = 0;
if isfield(constraints, 'min_earth_altitude_km')
    earth_margin = constraints.min_earth_altitude_km;
end
if isfield(constraints, 'min_moon_altitude_km')
    moon_margin = constraints.min_moon_altitude_km;
end
nlp.min_earth = (nlp.model.earth_radius_km + earth_margin) / nlp.model.distance_km;
nlp.min_moon = (nlp.model.moon_radius_km + moon_margin) / nlp.model.distance_km;
end
