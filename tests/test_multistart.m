function tests = test_multistart
%TEST_MULTISTART Exercise real candidate refinement and validated-cost selection.
tests = functiontests(localfunctions);
end

function testSelectsLowestValidatedAttempt(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
cleanup = onCleanup(@() path(old_path));
addpath(root);
[problem, options] = orb2ds.load_case(fullfile(root, 'examples', 'config_example.m'));
options.n_starts = 2;
options.solver.max_iterations = 0;
options.output.display = false;
options.solver.display = 'off';
options.output.keep_attempt_solutions = true;
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
