function [vector, value, summary, best_feasible] = solve_fmincon(nlp, initial, stage)
%SOLVE_FMINCON Run one stage with native options and compact stopping metadata.
%
% PROTOTYPE:
%   [x, f, summary, best] = orb2ds.internal.solve_fmincon(nlp, x0, stage)
% INPUT:
%   nlp    Runtime shooting layout, callbacks, bounds and resolved options.
%   x0     Normalized decision-vector column.
%   stage  'feasibility' for zero cost, or 'delta_v' for normalized total burn.
% OUTPUT:
%   x/f    Returned normalized decision vector and objective value.
%   summary Compact serializable options, stopping information and timings.
%   best   Optional distinct best-feasible vector, for independent validation.
%
%   NLP variables/residuals are normalized. Native options override common
%   settings, including MaxIterations for either stage. Derivative callbacks
%   are owned by Orb2DS and cannot be replaced through numerical settings.

options = nlp.options.solver;
iterations = options.max_iterations;
if strcmp(stage, 'feasibility')
    iterations = options.max_iterations_feasibility;
end
settings = optimoptions('fmincon', 'Algorithm', options.fmincon.algorithm, ...
    'SpecifyObjectiveGradient', true, 'SpecifyConstraintGradient', true, ...
    'ConstraintTolerance', options.constraint_tolerance, ...
    'OptimalityTolerance', options.optimality_tolerance, ...
    'StepTolerance', options.step_tolerance, ...
    'MaxIterations', iterations, 'MaxFunctionEvaluations', options.max_function_evaluations, ...
    'Display', options.display);
names = fieldnames(options.fmincon.options);
for index = 1:numel(names)
    settings.(names{index}) = options.fmincon.options.(names{index});
end
assert(ismember(settings.Algorithm, {'sqp', 'interior-point', 'active-set', 'sqp-legacy'}), ...
    'orb2ds:SolverAlgorithm', 'This NLP requires an algorithm supporting nonlinear constraints.');
assert(settings.SpecifyObjectiveGradient && settings.SpecifyConstraintGradient && ...
    isempty(settings.OutputFcn) && isempty(settings.PlotFcn) && ...
    isempty(settings.HessianFcn) && isempty(settings.HessianMultiplyFcn), ...
    'orb2ds:NativeOptions', 'Orb2DS owns the derivative and callback interfaces.');

objective = @(x) orb2ds.internal.objective(x, nlp);
if strcmp(stage, 'feasibility')
    objective = @zero_objective;
end
timer = tic;
[vector, value, flag, output] = fmincon(objective, initial, nlp.A, nlp.b, ...
    [], [], nlp.lower, nlp.upper, @(x) orb2ds.internal.constraints(x, nlp), settings);
summary = struct('stage', stage, 'name', 'fmincon', 'evaluation', 'matlab', ...
    'exitflag', flag, 'converged', flag > 0, 'elapsed_seconds', toc(timer));
for name = {'iterations', 'funcCount', 'constrviolation', 'firstorderopt', ...
        'stepsize', 'algorithm', 'message'}
    if isfield(output, name{1})
        summary.(name{1}) = output.(name{1});
    end
end
toolbox = ver('optim');
summary.version = toolbox.Version;
summary.matlab_version = version;
summary.effective_options = struct();
names = unique([names; {'Algorithm'; 'SpecifyObjectiveGradient'; 'SpecifyConstraintGradient'; ...
    'ConstraintTolerance'; 'OptimalityTolerance'; 'StepTolerance'; 'MaxIterations'; ...
    'MaxFunctionEvaluations'; 'Display'}]);
for index = 1:numel(names)
    summary.effective_options.(names{index}) = settings.(names{index});
end
best_feasible = [];
if isfield(output, 'bestfeasible') && ~isempty(output.bestfeasible) && ...
        isfield(output.bestfeasible, 'x') && ~isempty(output.bestfeasible.x) && ...
        ~isequal(output.bestfeasible.x(:), vector(:))
    best_feasible = output.bestfeasible.x(:);
end
end

function [value, gradient] = zero_objective(vector)
%ZERO_OBJECTIVE Keep the feasibility stage independent of delta-v.
value = 0;
gradient = zeros(size(vector));
end
