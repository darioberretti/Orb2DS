function options = options(supplied)
%OPTIONS Resolve numerical defaults and validate shared leaf types.

options = orb2ds.internal.merge_options( ...
    orb2ds.defaults.numerical_options(), supplied, 'options');
orb2ds.internal.resolve_constraint_tolerances(options);
validateattributes(options.solver.constraint_tolerance, {'double'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(options.n_starts, {'double'}, {'scalar', 'integer', 'positive'});
validateattributes(options.mesh.max_step_days, {'double'}, {'scalar', 'positive', 'finite'});
events = {'departure', 'moon_entry', 'moon_periapsis', 'moon_exit', 'earth_periapsis'};
options.mesh.refinement.from = validatestring(options.mesh.refinement.from, events);
options.mesh.refinement.to = validatestring(options.mesh.refinement.to, events);
validateattributes(options.mesh.refinement.from_offset_days, {'double'}, ...
    {'scalar', 'real', 'finite'});
validateattributes(options.mesh.refinement.factor, {'double'}, ...
    {'scalar', 'real', 'finite', '>=', 1});
validateattributes(options.output.plot_initial_guess, {'logical'}, {'scalar'});
validateattributes(options.output.plot_nlp_guess, {'logical'}, {'scalar'});
validateattributes(options.integration.relative_tolerance, {'double'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(options.integration.absolute_tolerance, {'double'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(options.solver.minimum_segment_days, {'double'}, ...
    {'scalar', 'positive', 'finite'});
options.solver.name = validatestring(options.solver.name, {'fmincon', 'ipopt'});
options.solver.evaluation = validatestring(options.solver.evaluation, {'matlab', 'casadi'});
options.solver.display = validatestring(options.solver.display, ...
    {'off', 'final', 'iter', 'iter-detailed'});
options.solver.fmincon.algorithm = validatestring(options.solver.fmincon.algorithm, ...
    {'sqp', 'interior-point', 'active-set', 'sqp-legacy'});
assert(~strcmp(options.solver.name, 'fmincon') || ...
    strcmp(options.solver.evaluation, 'matlab'), 'orb2ds:SolverCombination', ...
    'fmincon currently requires solver.evaluation = ''matlab''.');
for block = {'fmincon', 'ipopt', 'casadi', 'cvodes'}
    native = options.solver.(block{1});
    if strcmp(block{1}, 'fmincon')
        native = native.options;
    end
    check_native_values(native);
end
end

function check_native_values(value)
%CHECK_NATIVE_VALUES Keep saved settings free of callbacks and runtime objects.
if isstruct(value)
    assert(isscalar(value), 'orb2ds:NativeOptions', 'Native option blocks must be scalar structures.');
    names = fieldnames(value);
    for index = 1:numel(names)
        check_native_values(value.(names{index}));
    end
elseif iscell(value)
    for index = 1:numel(value)
        check_native_values(value{index});
    end
else
    assert(isnumeric(value) || islogical(value) || ischar(value) || isstring(value), ...
        'orb2ds:NativeOptions', 'Native options must contain serializable data, not callbacks or objects.');
end
end
