function problem = check_problem(problem)
%CHECK_PROBLEM Validate a scientific request without supplying physical limits.

assert(isstruct(problem) && isscalar(problem), 'orb2ds:Problem', ...
    'problem must be a scalar structure.');
unknown = setdiff(fieldnames(problem), {'orbit', 'target', 'constraints', 'database'});
assert(isempty(unknown), 'orb2ds:UnknownField', 'Unknown problem field: %s.', ...
    strjoin(unknown, ', '));
problem.orbit = orb2ds.internal.check_orbit(problem.orbit);
target = problem.target;
unknown = setdiff(fieldnames(target), {'vinf_km_s', 'frame', 'solar_geometry'});
assert(isempty(unknown), 'orb2ds:UnknownField', 'Unknown target field: %s.', ...
    strjoin(unknown, ', '));
validateattributes(target.vinf_km_s, {'double'}, {'size', [3, 1], 'real', 'finite'});
assert(norm(target.vinf_km_s) > 0, 'orb2ds:Target', 'The excess velocity must be nonzero.');
target.frame = validatestring(target.frame, {'eci', 'earth_sun_rth'});
if strcmp(target.frame, 'earth_sun_rth')
    geometry = target.solar_geometry;
    assert(isempty(setxor(fieldnames(geometry), {'angle_ref_rad'; 'rate_rad_day'})), ...
        'orb2ds:Geometry', 'Specify solar_geometry.angle_ref_rad and rate_rad_day.');
    validateattributes(geometry.angle_ref_rad, {'double'}, {'scalar', 'real', 'finite'});
    validateattributes(geometry.rate_rad_day, {'double'}, {'scalar', 'real', 'finite'});
end
problem.target = target;
if ~isfield(problem, 'constraints')
    problem.constraints = struct();
end
constraints = problem.constraints;
allowed = {'initial_time_days', 'initial_phase', 'max_wait_time_days', ...
    'max_transfer_time_days', 'max_total_time_days', 'final_time_days', ...
    'min_earth_altitude_km', 'min_moon_altitude_km', 'impulse_nodes'};
unknown = setdiff(fieldnames(constraints), allowed);
assert(isempty(unknown), 'orb2ds:UnknownField', 'Unknown constraint: %s.', ...
    strjoin(unknown, ', '));
names = fieldnames(constraints);
for index = 1:numel(names)
    name = names{index};
    value = constraints.(name);
    if isempty(value)
        constraints = rmfield(constraints, name);
        continue
    end
    if strcmp(name, 'final_time_days')
        error('orb2ds:Unsupported', ...
            'Exact and windowed final epochs require the future final-time algorithm.');
    elseif strcmp(name, 'impulse_nodes')
        constraints.(name) = validatestring(value, {'all', 'endpoints'});
    else
        validateattributes(value, {'double'}, {'scalar', 'real', 'finite'});
        if strcmp(name, 'initial_phase')
            assert(value >= 0 && value <= 1, 'orb2ds:Phase', 'Use normalized phase in [0,1].');
            constraints.(name) = mod(value, 1);
        elseif ~strcmp(name, 'initial_time_days')
            assert(value >= 0, 'orb2ds:Constraint', '%s cannot be negative.', name);
            if ismember(name, {'max_total_time_days', 'max_transfer_time_days'})
                assert(value > 0, 'orb2ds:Constraint', ...
                    '%s must allow a strictly positive flight duration.', name);
            end
        end
    end
end
problem.constraints = constraints;
end
