function [vector, value, summary, best_feasible] = solve_ipopt(nlp, graph, initial, stage)
%SOLVE_IPOPT Run one CasADi/IPOPT stage and retain compact native diagnostics.
%
% PROTOTYPE:
%   [x, f, summary, best] = orb2ds.internal.solve_ipopt(nlp, graph, x0, stage)
% INPUT:
%   nlp    Runtime shooting layout, bounds and resolved options.
%   graph  Live CasADi problem from build_casadi_problem, including owners.
%   x0     Normalized decision-vector column.
%   stage  'feasibility' for zero cost, or 'delta_v' for normalized total burn.
% OUTPUT:
%   x/f    Returned normalized decision vector and objective value.
%   summary Compact serializable options, stopping information and timings.
%   best   Empty: this adapter does not collect intermediate feasible iterates.
%
%   MATLAB callbacks supply first derivatives and require limited-memory.
%   Native IPOPT options override common settings for both stages. Transfer
%   acceptance always uses the separate MATLAB physical validator.

options = nlp.options.solver;
iterations = options.max_iterations;
if strcmp(stage, 'feasibility')
    iterations = options.max_iterations_feasibility;
end
levels = struct('off', 0, 'final', 0, 'iter', 5, 'iter_detailed', 7);
settings = struct('print_time', false, 'error_on_fail', false, 'show_eval_warnings', false);
names = fieldnames(options.casadi);
assert(~isfield(options.casadi, 'ipopt'), 'orb2ds:NativeOptions', ...
    'Use solver.ipopt for native IPOPT options.');
for index = 1:numel(names)
    settings.(names{index}) = options.casadi.(names{index});
end
settings.ipopt = struct('tol', options.optimality_tolerance, ...
    'constr_viol_tol', options.constraint_tolerance, 'max_iter', iterations, ...
    'hessian_approximation', 'limited-memory', 'acceptable_iter', 0, ...
    'bound_relax_factor', 0, 'option_file_name', '', 'sb', 'yes', ...
    'print_level', levels.(strrep(options.display, '-', '_')));
names = fieldnames(options.ipopt);
for index = 1:numel(names)
    settings.ipopt.(names{index}) = options.ipopt.(names{index});
end
assert(~strcmp(options.evaluation, 'matlab') || ...
    strcmp(settings.ipopt.hessian_approximation, 'limited-memory'), ...
    'orb2ds:SolverHessian', 'MATLAB callbacks provide first derivatives; use limited-memory.');
definition = graph.nlp;
if strcmp(stage, 'feasibility')
    definition.f = 0 * definition.f;
end
timer = tic;
solver = casadi.nlpsol(['orb2ds_', stage], 'ipopt', definition, settings);
build_seconds = toc(timer);
timer = tic;
solution = solver('x0', initial, 'lbx', nlp.lower, 'ubx', nlp.upper, ...
    'lbg', graph.lower, 'ubg', graph.upper);
elapsed_seconds = toc(timer);
stats = solver.stats();
vector = full(solution.x);
value = full(solution.f);
status = stats.return_status;
converged = strcmp(status, 'Solve_Succeeded');
acceptable = strcmp(status, 'Solved_To_Acceptable_Level');
flag = -1;
if converged
    flag = 1;
elseif acceptable
    flag = 2;
elseif ismember(status, {'Maximum_Iterations_Exceeded', 'Maximum_CpuTime_Exceeded', ...
        'Maximum_WallTime_Exceeded', 'User_Requested_Stop', 'Search_Direction_Becomes_Too_Small'})
    flag = 0;
end
summary = struct('stage', stage, 'name', 'ipopt', 'evaluation', options.evaluation, ...
    'algorithm', 'interior-point', 'exitflag', flag, 'return_status', status, ...
    'converged', converged, 'acceptable', acceptable, 'iterations', stats.iter_count, ...
    'elapsed_seconds', elapsed_seconds, 'build_seconds', build_seconds, ...
    'casadi_version', casadi.CasadiMeta.version(), 'effective_options', settings, ...
    'unused_common_options', {{'max_function_evaluations', 'step_tolerance'}});
for name = {'n_call_nlp_f', 'n_call_nlp_g', 'n_call_nlp_grad_f', 'n_call_nlp_jac_g'}
    if isfield(stats, name{1})
        summary.(name{1}) = stats.(name{1});
    end
end
if isfield(stats, 'iterations')
    for name = {'inf_pr', 'inf_du', 'mu'}
        if isfield(stats.iterations, name{1}) && ~isempty(stats.iterations.(name{1}))
            values = stats.iterations.(name{1});
            summary.(name{1}) = values(end);
        end
    end
end
if strcmp(options.display, 'final')
    fprintf('IPOPT %s: %s; %d iterations\n', stage, status, stats.iter_count);
end
best_feasible = [];
end
