function result = optimize_transfer(problem, seed, supplied)
%OPTIMIZE_TRANSFER Solve and independently validate one compact shooting guess.
%
% PROTOTYPE:
%   result = orb2ds.optimize_transfer(problem, seed, options)
%
% DESCRIPTION:
%   Use the thesis Oshima regularized impulses and spatial multiple shooting.
%   First solve the zero-objective feasibility problem when enabled, then
%   minimize total delta-v with the same constraints using fmincon SQP.
%   Validate both returned stage candidates and retain the lowest-cost
%   feasible record. A feasible candidate without optimization convergence is
%   labeled separately. A failed final candidate is retained compactly.
%
% INPUT:
%   problem  Current orbit, target and constraints. Database is not read.
%   seed     Compact discretized guess or previous solution, even for a
%            different target; compatible orbit/model/conventions required.
%   options  Optional numerical settings. mesh settings do not remesh seed.
%            output.display controls stage/physical summaries; solver.display
%            independently controls fmincon's native iteration table.
% OUTPUT:
%   result   Shared compact contract in docs/CONTRACTS.md. Never contains
%            sampled trajectories, callbacks or packed optimizer vectors.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
seed = orb2ds.internal.check_record(seed);
nlp = orb2ds.internal.build_nlp(problem, seed, options);
result = orb2ds.internal.empty_result(problem, options);
result.seed = seed;
settings = optimoptions('fmincon', 'Algorithm', 'sqp', ...
    'SpecifyObjectiveGradient', true, 'SpecifyConstraintGradient', true, ...
    'ConstraintTolerance', options.solver.constraint_tolerance, ...
    'OptimalityTolerance', options.solver.optimality_tolerance, ...
    'StepTolerance', options.solver.step_tolerance, ...
    'MaxFunctionEvaluations', options.solver.max_function_evaluations, ...
    'Display', options.solver.display);
nonlinear = @(vector) orb2ds.internal.constraints(vector, nlp);
vectors = {};
stages = {};
initial = nlp.initial;
if options.output.display
    fprintf('\norb2ds optimization: %d nodes, seed delta-v %.6f m/s, flight %.6f days\n', ...
        numel(seed.nodes.time_days), 1000 * sum(vecnorm(seed.nodes.delta_v_km_s, 2, 2)), ...
        seed.nodes.time_days(end) - seed.nodes.time_days(1));
end
if options.solver.run_feasibility
    settings.MaxIterations = options.solver.max_iterations_feasibility;
    if options.output.display
        fprintf('Stage 1: feasibility, zero objective; limit %d iterations\n', ...
            settings.MaxIterations);
    end
    stage_timer = tic;
    [initial, ~, flag, output] = fmincon(@zero_objective, initial, ...
        nlp.A, nlp.b, [], [], nlp.lower, nlp.upper, nonlinear, settings);
    vectors{end + 1} = initial;
    stages{end + 1} = solver_summary(flag, output, 'feasibility');
    result.solver.feasibility = stages{end};
    if options.output.display
        fprintf('Stage 1 finished: exitflag %d, %d iterations, %.2f s\n', ...
            flag, output.iterations, toc(stage_timer));
    end
end
settings.MaxIterations = options.solver.max_iterations;
if options.output.display
    fprintf('Stage 2: minimize delta-v; limit %d iterations\n', settings.MaxIterations);
    fprintf('Native fmincon f(x) is normalized: delta-v [m/s] = f(x) * %.9g\n', ...
        nlp.model.velocity_km_s * 1000);
end
stage_timer = tic;
[final, value, flag, output] = fmincon(@(vector) orb2ds.internal.objective(vector, nlp), ...
    initial, nlp.A, nlp.b, [], [], nlp.lower, nlp.upper, nonlinear, settings);
vectors{end + 1} = final;
stages{end + 1} = solver_summary(flag, output, 'delta_v');
result.solver.optimization = stages{end};
result.solver.final_objective_delta_v_m_s = value * nlp.model.velocity_km_s * 1000;
if options.output.display
    fprintf('Stage 2 finished: exitflag %d, %d iterations, %.2f s\n', ...
        flag, output.iterations, toc(stage_timer));
    fprintf('Independent physical validation of returned stage candidates...\n');
end
if isfield(output, 'bestfeasible') && ~isempty(output.bestfeasible) && ...
        isfield(output.bestfeasible, 'x') && ~isempty(output.bestfeasible.x) && ...
        ~isequal(output.bestfeasible.x(:), final(:))
    vectors{end + 1} = output.bestfeasible.x(:);
    stages{end + 1} = solver_summary(flag, output, 'delta_v_best_feasible');
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
    stages{selected_stage}.exitflag > 0;
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
    fprintf('  Segment defects: position %.3g km; velocity %.3g km/s\n', ...
        result.validation.max_position_defect_km, result.validation.max_velocity_defect_km_s);
    fprintf('  Minimum altitude: Earth %.6f km; Moon %.6f km\n', ...
        result.validation.min_earth_altitude_km, result.validation.min_moon_altitude_km);
    fprintf('  Shooting feasible: %d; chained feasible: %d; chained position error %.3g km\n', ...
        result.validation.is_feasible, result.validation.chained.is_feasible, ...
        result.validation.chained.endpoint_position_error_km);
end
end

function [value, gradient] = zero_objective(vector)
%ZERO_OBJECTIVE Preserve the separate thesis feasibility stage.
value = 0;
gradient = zeros(size(vector));
end

function summary = solver_summary(flag, output, stage)
%SOLVER_SUMMARY Keep stopping information without optimizer vectors or callbacks.
summary = struct('stage', stage, 'exitflag', flag);
for name = {'iterations', 'funcCount', 'constrviolation', 'firstorderopt', ...
        'stepsize', 'algorithm', 'message'}
    if isfield(output, name{1})
        summary.(name{1}) = output.(name{1});
    end
end
end
