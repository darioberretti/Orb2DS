function options = options(supplied)
%OPTIONS Resolve numerical defaults and validate shared leaf types.

options = orb2ds.internal.merge_options( ...
    orb2ds.defaults.numerical_options(), supplied, 'options');
validateattributes(options.n_starts, {'double'}, {'scalar', 'integer', 'positive'});
validateattributes(options.mesh.max_step_days, {'double'}, {'scalar', 'positive', 'finite'});
validateattributes(options.integration.relative_tolerance, {'double'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(options.integration.absolute_tolerance, {'double'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(options.solver.minimum_segment_days, {'double'}, ...
    {'scalar', 'positive', 'finite'});
end
