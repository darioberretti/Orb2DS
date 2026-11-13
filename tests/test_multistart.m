function tests = test_multistart
%TEST_MULTISTART Exercise real candidate refinement and validated-cost selection.
tests = functiontests(localfunctions);
end

function testSelectsLowestValidatedAttempt(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
cleanup = onCleanup(@() path(old_path));
addpath(root);
[problem, options] = orb2ds.load_case(fullfile(root, 'examples', 'config_transfer.m'));
% Solver controls are fixed for this regression, independent of user edits
% to the copyable example's selected optimizer, tolerances and plot flags.
defaults = orb2ds.defaults.numerical_options();
options.solver = defaults.solver;
options.integration = defaults.integration;
options.mesh = defaults.mesh;
options.output = defaults.output;
options.n_starts = 2;
options.solver.max_iterations = 0;
options.output.display = false;
options.solver.display = 'off';
options.output.keep_attempt_solutions = true;
options.validation.require_pass = true;
result = orb2ds.find_transfer(problem, options);
verifyNumElements(testCase, result.attempts, 2);
valid = [result.attempts.is_feasible];
verifyTrue(testCase, any(valid));
verifyNotEmpty(testCase, result.solution);
verifyEqual(testCase, result.solution.metrics.delta_v_m_s, ...
    min([result.attempts(valid).delta_v_m_s]), 'AbsTol', 1e-10);
verifyFalse(testCase, isfield(result.inputs.problem, 'database'));
for index = find(valid)
    verifyNotEmpty(testCase, result.attempts(index).solution);
    verifyFalse(testCase, isfield(result.attempts(index).solution, 'trajectory'));
end
end

function testExploratoryRankingUsesSolverConvergenceThenCost(testCase)
validated = struct('is_feasible', true, 'solver_converged', false, 'delta_v_m_s', 270);
converged = struct('is_feasible', false, 'solver_converged', true, 'delta_v_m_s', 280);
verifyTrue(testCase, orb2ds.internal.prefer_transfer(converged, validated, false));
verifyFalse(testCase, orb2ds.internal.prefer_transfer(converged, validated, true));
cheaper = converged;
cheaper.delta_v_m_s = 275;
verifyTrue(testCase, orb2ds.internal.prefer_transfer(cheaper, converged, false));
end
