function tests = test_solver_backends
%TEST_SOLVER_BACKENDS Compare equivalent NLPs, native options and real solver calls.
%   CasADi-specific tests are explicitly skipped when it is not on the path.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
data = load(fullfile(root, 'tests', 'fixtures', 'validated_transfer.mat'));
testCase.TestData.reference = data;
options = orb2ds.defaults.numerical_options();
options.output.display = false;
options.solver.max_iterations = 0;
options.solver.max_iterations_feasibility = 0;
testCase.TestData.options = options;

% Short independent arcs give a cheap, nontrivial test of every Jacobian block.
model = data.problem.orbit.model;
scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
state = data.problem.orbit.state_ref ./ scale.';
state = orb2ds.internal.propagate(state, [0, 0.2 * 3.395596937863704], model, options);
states = zeros(3, 6);
states(1, :) = state.';
for index = 2:3
    state = orb2ds.internal.propagate(state, [0, 0.03], model, options);
    states(index, :) = state.';
end
burns = [0.01, -0.005, 0.003; -0.001, 0.002, 0; -0.02, 0, 0];
states(:, 4:6) = states(:, 4:6) + burns / model.velocity_km_s;
seed = data.solution;
seed.nodes = struct('time_days', [2; 2.03; 2.06] * model.time_days, ...
    'state_post', states .* scale, 'delta_v_km_s', burns);
seed.events = struct('moon_periapsis_node', 2);
seed.timing = struct('departure_phase', 0.2);
testCase.TestData.seed = seed;
problem = data.problem;
problem.constraints = struct();
problem.target = struct('frame', 'earth_sun_rth', 'vinf_km_s', [2; -1; 0.1], ...
    'solar_geometry', struct('angle_ref_rad', 0.4, 'rate_rad_day', 2 * pi / 365.25));
testCase.TestData.problem = problem;
end

function testSelectionAndNativeOptionValidation(testCase)
options = orb2ds.internal.options(struct());
verifyEqual(testCase, options.solver.name, 'fmincon');
verifyEqual(testCase, options.solver.fmincon.algorithm, 'sqp');
options.solver.ipopt.mu_strategy = 'adaptive';
resolved = orb2ds.internal.options(options);
verifyEqual(testCase, resolved.solver.ipopt.mu_strategy, 'adaptive');
options.solver.evaluation = 'casadi';
verifyError(testCase, @() orb2ds.internal.options(options), 'orb2ds:SolverCombination');
options.solver.evaluation = 'matlab';
options.solver.fmincon.options.OutputFcn = @(x) x;
verifyError(testCase, @() orb2ds.internal.options(options), 'orb2ds:NativeOptions');
verifyError(testCase, @() orb2ds.internal.options(struct('typo', 1)), 'orb2ds:UnknownField');
end

function testAllFminconAlgorithmsAndNativePrecedence(testCase)
options = testCase.TestData.options;
options.solver.max_iterations = 10;
options.solver.fmincon.options.MaxIterations = 0;
for algorithm = {'sqp', 'interior-point', 'active-set', 'sqp-legacy'}
    options.solver.fmincon.algorithm = algorithm{1};
    nlp = orb2ds.internal.build_nlp(testCase.TestData.problem, testCase.TestData.seed, options);
    [vector, value, summary] = orb2ds.internal.solve_fmincon(nlp, nlp.initial, 'delta_v');
    verifyTrue(testCase, all(isfinite(vector)) && isfinite(value));
    verifyEqual(testCase, summary.effective_options.Algorithm, algorithm{1});
    verifyEqual(testCase, summary.effective_options.MaxIterations, 0);
end
end

function testEquivalentValuesAndJacobiansAllTimingCases(testCase)
require_casadi(testCase);
options = testCase.TestData.options;
options.solver.name = 'ipopt';
options.solver.constraint_tolerances.dynamics.position_km = 1e-4;
options.solver.constraint_tolerances.target.velocity_km_s = 1e-7;
options.solver.constraint_tolerances.time_days = 1e-8;
for initial = 0:3
    problem = testCase.TestData.problem;
    problem.constraints = struct('max_transfer_time_days', 10, 'max_total_time_days', 11, ...
        'max_wait_time_days', 3);
    if bitand(initial, 1)
        problem.constraints.initial_time_days = 4;
    end
    if bitand(initial, 2)
        problem.constraints.initial_phase = 0.17;
    end
    nlp = orb2ds.internal.build_nlp(problem, testCase.TestData.seed, options);
    if ~isempty(nlp.wait_index)
        nlp.initial(nlp.wait_index) = 0.3;
    end
    compare_graphs(testCase, nlp);
end
end

function testPlanarSeedSparsityAndPhaseWrap(testCase)
require_casadi(testCase);
options = testCase.TestData.options;
options.solver.name = 'ipopt';
problem = testCase.TestData.problem;
problem.target = testCase.TestData.reference.problem.target;
problem.constraints.impulse_nodes = 'endpoints';
nlp = orb2ds.internal.build_nlp(problem, testCase.TestData.seed, options);
nlp.initial(3:9:27) = 0;
nlp.initial(6:9:27) = 0;
nlp.initial(nlp.phase_index) = 1;
compare_graphs(testCase, nlp);
callback = orb2ds.internal.build_casadi_problem(nlp);
% Moving out of the planar seed must retain previously zero derivatives.
nlp.initial([3, 6, 12, 15]) = [0.001, -0.002, 0.003, 0.001];
nlp.initial(nlp.phase_index) = 0.2;
[~, ~, gc, geq] = orb2ds.internal.constraints(nlp.initial, nlp);
verifyEqual(testCase, full(callback.jacobian(nlp.initial)), ...
    full([geq.'; gc.'; nlp.A]), 'AbsTol', 1e-12);
end

function testIPOPTBothStagesAndNativePrecedence(testCase)
require_casadi(testCase);
options = testCase.TestData.options;
options.validation.require_pass = true;
options.solver.name = 'ipopt';
options.solver.max_iterations = 10;
options.solver.ipopt.max_iter = 0;
options.solver.ipopt.mu_strategy = 'adaptive';
for backend = {'matlab', 'casadi'}
    options.solver.evaluation = backend{1};
    result = orb2ds.optimize_transfer(testCase.TestData.problem, testCase.TestData.seed, options);
    for stage = {'feasibility', 'optimization'}
        summary = result.solver.(stage{1});
        verifyEqual(testCase, summary.effective_options.ipopt.max_iter, 0);
        verifyEqual(testCase, summary.effective_options.ipopt.mu_strategy, 'adaptive');
        verifyEqual(testCase, summary.evaluation, backend{1});
        verifyEqual(testCase, summary.return_status, 'Maximum_Iterations_Exceeded');
        verifyFalse(testCase, summary.converged);
    end
    verifyEqual(testCase, result.status, 'no_validated_solution');
end
end

function testValidatedRecordAndCompactPersistenceBothRoutes(testCase)
require_casadi(testCase);
options = testCase.TestData.options;
options.solver.name = 'ipopt';
options.solver.run_feasibility = false;
% IPOPT normally moves x0 away from bounds; suppress that for this reuse test.
options.solver.ipopt.bound_push = 1e-12;
options.solver.ipopt.bound_frac = 1e-12;
for backend = {'matlab', 'casadi'}
    options.solver.evaluation = backend{1};
    reference = testCase.TestData.reference;
    result = orb2ds.optimize_transfer(reference.problem, reference.solution, options);
    verifyTrue(testCase, result.validation.is_feasible);
    verifyTrue(testCase, result.validation.chained.is_feasible);
    verifyEqual(testCase, result.status, 'feasible_without_optimization_convergence');
    verifyFalse(testCase, contains(jsonencode(result), 'last_jacobian'));
    verifyFalse(testCase, contains(jsonencode(result), 'state_history'));
    filename = [tempname, '.mat'];
    cleanup = onCleanup(@() delete(filename));
    save(filename, 'result');
    restored = load(filename);
    verifyEqual(testCase, restored.result, result);
end
end

function testIPOPTIterationsAndHessianSelection(testCase)
require_casadi(testCase);
options = testCase.TestData.options;
options.solver.name = 'ipopt';
options.solver.ipopt.max_iter = 2;
for backend = {'matlab', 'casadi'}
    options.solver.evaluation = backend{1};
    nlp = orb2ds.internal.build_nlp(testCase.TestData.problem, testCase.TestData.seed, options);
    graph = orb2ds.internal.build_casadi_problem(nlp);
    [vector, value, summary] = orb2ds.internal.solve_ipopt(nlp, graph, nlp.initial, 'delta_v');
    verifyTrue(testCase, all(isfinite(vector)) && isfinite(value));
    verifyEqual(testCase, summary.iterations, 2);
    nlp.options.solver.ipopt.hessian_approximation = 'exact';
    if strcmp(backend{1}, 'matlab')
        verifyError(testCase, @() orb2ds.internal.solve_ipopt(nlp, graph, nlp.initial, 'delta_v'), ...
            'orb2ds:SolverHessian');
    else
        nlp.options.solver.ipopt.max_iter = 1;
        [~, ~, exact] = orb2ds.internal.solve_ipopt(nlp, graph, nlp.initial, 'delta_v');
        verifyEqual(testCase, exact.effective_options.ipopt.hessian_approximation, 'exact');
    end
end
end

function compare_graphs(testCase, nlp)
%COMPARE_GRAPHS Check both routes against independent MATLAB residual evaluation.
[c, ceq, gc, geq] = orb2ds.internal.constraints(nlp.initial, nlp);
expected = [ceq; c; nlp.A * nlp.initial - nlp.b];
expected_jacobian = full([geq.'; gc.'; nlp.A]);
for backend = {'matlab', 'casadi'}
    nlp.options.solver.evaluation = backend{1};
    graph = orb2ds.internal.build_casadi_problem(nlp);
    actual = full(graph.constraints(nlp.initial));
    actual_jacobian = full(graph.jacobian(nlp.initial));
    verifyLessThan(testCase, norm(actual - expected, inf), 1e-7);
    verifyLessThan(testCase, norm(actual_jacobian - expected_jacobian, 'fro') / ...
        max(1, norm(expected_jacobian, 'fro')), 1e-7);
    [cost, gradient] = orb2ds.internal.objective(nlp.initial, nlp);
    [actual_cost, actual_gradient] = graph.objective(nlp.initial);
    verifyEqual(testCase, full(actual_cost), cost, 'AbsTol', 1e-13);
    verifyEqual(testCase, full(actual_gradient), gradient, 'AbsTol', 1e-13);
end
end

function require_casadi(testCase)
%REQUIRE_CASADI Make an unavailable optional dependency visible as a skipped test.
assumeFalse(testCase, isempty(which('casadi.nlpsol')), 'CasADi is not on the MATLAB path.');
end
