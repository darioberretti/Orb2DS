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
%   Validate both returned stage candidates and retain the lowest-cost
%   record passing local and chained checks. A physically accepted record
%   without optimization convergence is
%   labeled separately. A failed final candidate is retained compactly.
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
    graph = orb2ds.internal.build_casadi_problem(nlp);
    solve = @(initial, stage) orb2ds.internal.solve_ipopt(nlp, graph, initial, stage);
    result.solver.graph_build_seconds = graph.build_seconds;
    result.solver.integrator_options = graph.integrator_options;
end
vectors = {};
stages = {};
initial = nlp.initial;
if options.output.display
    fprintf('\norb2ds optimization: %d nodes, seed delta-v %.6f m/s, flight %.6f days\n', ...
        numel(seed.nodes.time_days), 1000 * sum(vecnorm(seed.nodes.delta_v_km_s, 2, 2)), ...
        seed.nodes.time_days(end) - seed.nodes.time_days(1));
    fprintf('Solver: %s; evaluation: %s\n', options.solver.name, options.solver.evaluation);
    a = nlp.accuracy;
    fprintf('Accuracy: position %.3g km; velocity %.3g km/s; time %.3g days; exceptions %d\n', ...
        a.position_km, a.velocity_km_s, a.time_days, a.use_exceptions);
    fprintf('  Dynamics %.3g km / %.3g km/s; departure %.3g km / %.3g km/s\n', ...
        a.dynamics.position_km, a.dynamics.velocity_km_s, a.departure.position_km, ...
        a.departure.velocity_km_s);
    fprintf('  Target %.3g km/s; radial speed %.3g km/s; clearance %.3g km\n', ...
        a.target.velocity_km_s, a.periapsis.radial_velocity_km_s, a.clearance.altitude_km);
end
if options.solver.run_feasibility
    if options.output.display
        fprintf('Stage 1: feasibility, zero objective\n');
    end
    stage_timer = tic;
    [initial, ~, summary] = solve(initial, 'feasibility');
    vectors{end + 1} = initial;
    stages{end + 1} = summary;
    result.solver.feasibility = stages{end};
    if options.output.display
        fprintf('Stage 1 finished: exitflag %d, %d iterations, %.2f s\n', ...
            summary.exitflag, summary.iterations, toc(stage_timer));
    end
end
if options.output.display
    fprintf('Stage 2: minimize delta-v\n');
    fprintf('Native %s f(x) is normalized: delta-v [m/s] = f(x) * %.9g\n', ...
        options.solver.name, nlp.model.velocity_km_s * 1000);
end
stage_timer = tic;
[final, value, summary, best_feasible] = solve(initial, 'delta_v');
vectors{end + 1} = final;
stages{end + 1} = summary;
result.solver.optimization = stages{end};
result.solver.final_objective_delta_v_m_s = value * nlp.model.velocity_km_s * 1000;
if options.output.display
    fprintf('Stage 2 finished: exitflag %d, %d iterations, %.2f s\n', ...
        summary.exitflag, summary.iterations, toc(stage_timer));
    if isfield(summary, 'inf_pr')
        fprintf('  IPOPT final inf_pr: %.3g (NLP residual, not km)\n', summary.inf_pr);
    end
    fprintf('Independent physical validation of returned stage candidates...\n');
end
if ~isempty(best_feasible)
    vectors{end + 1} = best_feasible;
    summary.stage = 'delta_v_best_feasible';
    stages{end + 1} = summary;
end
best_cost = inf;
selected_stage = 0;
stage_checks = cell(numel(vectors), 1);
for index = 1:numel(vectors)
    candidate = orb2ds.internal.record_from_vector(vectors{index}, nlp);
    validation = orb2ds.validate_solution(candidate, problem, options);
    candidate.metrics.achieved_vinf_eci_km_s = validation.achieved_vinf_eci_km_s;
    candidate.metrics.target_error_km_s = validation.target_error_km_s;
    stage_checks{index} = struct('stage', stages{index}.stage, ...
        'delta_v_m_s', candidate.metrics.delta_v_m_s, 'checks', validation.checks, ...
        'position_defect_km', validation.max_position_defect_km, ...
        'velocity_defect_km_s', validation.max_velocity_defect_km_s, ...
        'target_error_km_s', validation.target_error_km_s, ...
        'min_earth_altitude_km', validation.min_earth_altitude_km, ...
        'min_moon_altitude_km', validation.min_moon_altitude_km);
    if validation.is_feasible && candidate.metrics.delta_v_m_s < best_cost
        result.solution = candidate;
        result.validation = validation;
        best_cost = candidate.metrics.delta_v_m_s;
        selected_stage = index;
    end
    if index == numel(vectors) && isempty(result.solution)
        result.candidate = candidate;
        result.validation = validation;
    end
end
result.solver.stage_validation = vertcat(stage_checks{:});
result.solver.converged = selected_stage > 0 && ...
    ismember(stages{selected_stage}.stage, {'delta_v', 'delta_v_best_feasible'}) && ...
    stages{selected_stage}.converged;
result.solver.selected_stage = '';
if selected_stage > 0
    result.solver.selected_stage = stages{selected_stage}.stage;
end
if isempty(result.solution)
    result.status = 'no_validated_solution';
elseif result.solver.converged
    result.status = 'feasible_converged';
else
    result.status = 'feasible_without_optimization_convergence';
end
if options.output.display
    fprintf('orb2ds result: %s; selected stage: %s\n', ...
        result.status, result.solver.selected_stage);
    fprintf('  Delta-v %.6f m/s; target error %.3g km/s\n', ...
        result.validation.delta_v_m_s, result.validation.target_error_km_s);
    fprintf('  Segment defects: position %.3g km (limit %.3g); velocity %.3g km/s (limit %.3g)\n', ...
        result.validation.max_position_defect_km, nlp.accuracy.dynamics.position_km, ...
        result.validation.max_velocity_defect_km_s, nlp.accuracy.dynamics.velocity_km_s);
    fprintf('  Departure errors: position %.3g km (limit %.3g); velocity %.3g km/s (limit %.3g)\n', ...
        result.validation.departure_position_error_km, nlp.accuracy.departure.position_km, ...
        result.validation.departure_velocity_error_km_s, nlp.accuracy.departure.velocity_km_s);
    names = fieldnames(result.validation.checks);
    failed = names(~cell2mat(struct2cell(result.validation.checks)));
    if ~isempty(failed)
        fprintf('  Failed physical checks: %s\n', strjoin(failed, ', '));
    end
    fprintf('  Minimum altitude: Earth %.6f km; Moon %.6f km\n', ...
        result.validation.min_earth_altitude_km, result.validation.min_moon_altitude_km);
    fprintf('  Shooting feasible: %d; chained feasible: %d; chained position error %.3g km\n', ...
        result.validation.local_is_feasible, result.validation.chained.is_feasible, ...
        result.validation.chained.endpoint_position_error_km);
end
end
