function result = empty_result(problem, options)
%EMPTY_RESULT Construct the shared compact result contract without database data.

if isfield(problem, 'database')
    problem = rmfield(problem, 'database');
end
constraints = problem.constraints;
redundant = {};
has_event = isfield(constraints, 'initial_time_days') || isfield(constraints, 'initial_phase');
if ~has_event && isfield(constraints, 'max_wait_time_days')
    redundant{end + 1} = 'max_wait_time_days: no separate initial event';
end
if isfield(constraints, 'max_total_time_days') && isfield(constraints, 'max_transfer_time_days')
    if constraints.max_transfer_time_days >= constraints.max_total_time_days
        redundant{end + 1} = 'max_transfer_time_days: implied by max_total_time_days';
    elseif ~has_event && constraints.max_total_time_days >= constraints.max_transfer_time_days
        redundant{end + 1} = 'max_total_time_days: implied by max_transfer_time_days';
    elseif isfield(constraints, 'max_wait_time_days') && constraints.max_total_time_days >= ...
            constraints.max_transfer_time_days + constraints.max_wait_time_days
        redundant{end + 1} = 'max_total_time_days: implied by the separate caps';
    end
end
result = struct('schema_version', 1, 'status', 'not_attempted', ...
    'solution', [], 'candidate', [], 'validation', struct(), 'seed', [], ...
    'solver', struct(), 'attempts', struct([]), ...
    'active_constraints', struct('supplied', constraints, 'redundant', {redundant}), ...
    'inputs', struct('problem', problem, 'options', options), ...
    'provenance', struct('library_version', '0.1.0-dev', 'matlab_version', version));
end
