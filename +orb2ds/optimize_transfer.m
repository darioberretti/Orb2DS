function result = optimize_transfer(problem, seed, supplied)
%OPTIMIZE_TRANSFER Solve and independently validate one compact shooting guess.
%
% PROTOTYPE:
%   result = orb2ds.optimize_transfer(problem, seed, options)
%
% DESCRIPTION:
%   Use Oshima regularized impulses and spatial multiple shooting.
%   First solve the zero-objective feasibility problem when enabled, then
%   minimize total delta-v with the same constraints using configurable
%   fmincon or CasADi/IPOPT (MATLAB callbacks or symbolic CVODES evaluation).
%   Evaluate local and chained checks on every returned stage candidate.
%   By default, prefer convergent delta-v solves and compare their costs.
%   validation.require_pass selects by lowest physically accepted cost.
%   The selected compact record and its physical diagnostics are retained.
%
% INPUT:
%   problem  Current orbit, target and constraints. Database is not read.
%   seed     Compact discretized guess or previous solution, even for a
%            different target; compatible orbit/model/conventions required.
%   options  Optional numerical settings. mesh settings do not remesh seed.
%            output.display controls stage/physical summaries; solver.display
%            independently controls the selected solver's native output.
% OUTPUT:
%   result   Shared compact contract in docs/CONTRACTS.md. Never contains
%            sampled trajectories, callbacks or packed optimizer vectors.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
seed = orb2ds.internal.check_record(seed);
orb2ds.internal.check_solver(options);
nlp = orb2ds.internal.build_nlp(problem, seed, options);
if options.output.plot_nlp_guess
    guess = orb2ds.internal.record_from_vector(nlp.initial, nlp);
    trajectory = orb2ds.reconstruct_trajectory(guess);
    figure_handle = orb2ds.plot_trajectory(trajectory, struct('show_defects', true));
    figure_handle.Name = 'NLP-transcribed initial guess';
    title(figure_handle.CurrentAxes, ...
        {'NLP-transcribed initial guess', figure_handle.CurrentAxes.Title.String}, 'Interpreter', 'latex');
    if strcmp(figure_handle.Visible, 'on')
        drawnow;
    end
end
result = orb2ds.internal.empty_result(problem, options);
result.seed = seed;
result.solver.name = options.solver.name;
result.solver.evaluation = options.solver.evaluation;
if strcmp(options.solver.name, 'fmincon')
    solve = @(initial, stage) orb2ds.internal.solve_fmincon(nlp, initial, stage);
else
    if options.output.display
        fprintf('\n[Orb2DS] IPOPT solver preparation\n\n');
        fprintf('  Evaluation                     : %s\n', options.solver.evaluation);
    end
    graph = orb2ds.internal.build_casadi_problem(nlp);
    solve = @(initial, stage) orb2ds.internal.solve_ipopt(nlp, graph, initial, stage);
    result.solver.graph_build_seconds = graph.build_seconds;
    result.solver.integrator_options = graph.integrator_options;
end
vectors = {};
stages = {};
initial = nlp.initial;
if options.output.display
    fprintf('\n[Orb2DS] Optimization setup\n\n');
    fprintf('  Shooting nodes                 : %d\n', numel(seed.nodes.time_days));
    fprintf('  Initial delta-v [m/s]          : %.6f\n', 1000 * sum(vecnorm(seed.nodes.delta_v_km_s, 2, 2)));
    fprintf('  Initial flight [days]          : %.6f\n', seed.nodes.time_days(end) - seed.nodes.time_days(1));
    fprintf('  Solver                         : %s\n', options.solver.name);
    fprintf('  Evaluation                     : %s\n', options.solver.evaluation);
    if options.solver.run_feasibility
        fprintf('  Feasibility stage              : ENABLED\n');
    else
        fprintf('  Feasibility stage              : DISABLED\n');
    end
    if options.validation.require_pass
        v = options.validation;
        fprintf('\n[Orb2DS] Physical acceptance thresholds\n\n');
        fprintf('  Position [km]                  : %.6g\n', v.position_km);
        fprintf('  Velocity [m/s]                 : %.6g\n', 1000 * v.velocity_km_s);
        fprintf('  Time [s]                       : %.6g\n', 86400 * v.time_days);
    end
end
if options.solver.run_feasibility
    if options.output.display
        fprintf('\n[Orb2DS] Feasibility search\n\n  Objective                    : zero\n');
    end
    stage_timer = tic;
    [initial, ~, summary] = solve(initial, 'feasibility');
    vectors{end + 1} = initial;
    stages{end + 1} = summary;
    result.solver.feasibility = stages{end};
    if options.output.display
        print_solver_summary(summary, toc(stage_timer), 'feasibility');
    end
end
if options.output.display
    fprintf('\n[Orb2DS] Delta-v minimization\n\n');
    fprintf('  Native objective conversion    : delta-v [m/s] = f(x) * %.9g\n', nlp.model.velocity_km_s * 1000);
end
stage_timer = tic;
[final, value, summary, best_feasible] = solve(initial, 'delta_v');
vectors{end + 1} = final;
stages{end + 1} = summary;
result.solver.optimization = stages{end};
result.solver.final_objective_delta_v_m_s = value * nlp.model.velocity_km_s * 1000;
if options.output.display
    print_solver_summary(summary, toc(stage_timer), 'delta-v minimization');
end
if options.output.display && options.validation.require_pass
    fprintf('\n[Orb2DS] Candidate validation\n\n');
    fprintf('  Returned records to check      : %d\n', numel(vectors) + ~isempty(best_feasible));
end
if ~isempty(best_feasible)
    vectors{end + 1} = best_feasible;
    summary.stage = 'delta_v_best_feasible';
    stages{end + 1} = summary;
end
require_pass = options.validation.require_pass;
best = [];
stage_checks = cell(numel(vectors), 1);
for index = 1:numel(vectors)
    candidate = orb2ds.internal.record_from_vector(vectors{index}, nlp);
    validation = orb2ds.validate_solution(candidate, problem, options);
    candidate.metrics.achieved_vinf_eci_km_s = validation.achieved_vinf_eci_km_s;
    candidate.metrics.target_error_km_s = validation.target_error_km_s;
    is_delta_v = ismember(stages{index}.stage, {'delta_v', 'delta_v_best_feasible'});
    current = struct('stage', stages{index}.stage, ...
        'solver_converged', is_delta_v && stages{index}.converged, ...
        'is_feasible', validation.is_feasible, ...
        'delta_v_m_s', candidate.metrics.delta_v_m_s, 'checks', validation.checks, ...
        'position_defect_km', validation.max_position_defect_km, ...
        'velocity_defect_km_s', validation.max_velocity_defect_km_s, ...
        'departure_position_error_km', validation.departure_position_error_km, ...
        'departure_velocity_error_km_s', validation.departure_velocity_error_km_s, ...
        'target_error_km_s', validation.target_error_km_s, ...
        'min_earth_altitude_km', validation.min_earth_altitude_km, ...
        'min_moon_altitude_km', validation.min_moon_altitude_km, 'chained', validation.chained);
    stage_checks{index} = current;
    % An unsuccessful zero-objective stage is a starting point for the delta-v solve.
    if (is_delta_v || current.is_feasible) && orb2ds.internal.prefer_transfer(current, best, require_pass)
        best = current;
        result.validation = validation;
        result.solution = [];
        result.candidate = [];
        if current.is_feasible
            result.solution = candidate;
        else
            result.candidate = candidate;
        end
    end
end
result.solver.stage_validation = vertcat(stage_checks{:});
result.solver.converged = best.solver_converged;
result.solver.selected_stage = best.stage;
if best.is_feasible && best.solver_converged
    result.status = 'feasible_converged';
elseif best.is_feasible
    result.status = 'feasible_without_optimization_convergence';
elseif require_pass
    result.status = 'no_validated_solution';
elseif best.solver_converged
    result.status = 'transfer_found';
else
    result.status = 'candidate_available';
end
if options.output.display
    orb2ds.print_result(result, require_pass);
end
end

function print_solver_summary(summary, elapsed, stage)
%PRINT_SOLVER_SUMMARY Separate native termination from physical acceptance.
fprintf('\n[Orb2DS] Solver result -- %s\n\n', stage);
if summary.converged
    fprintf('  Solver termination             : CONVERGED\n');
else
    fprintf('  Solver termination             : NOT CONVERGED\n');
end
if isfield(summary, 'return_status')
    fprintf('  Native status                  : %s\n', summary.return_status);
end
fprintf('  Exit flag                      : %d\n', summary.exitflag);
fprintf('  Iterations                     : %d\n', summary.iterations);
fprintf('  Elapsed time [s]               : %.2f\n', elapsed);
if isfield(summary, 'inf_pr')
    fprintf('  IPOPT scaled residual [-]      : %.6g\n', summary.inf_pr);
end
end
