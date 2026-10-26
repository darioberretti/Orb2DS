function tests = test_solution_contract
%TEST_SOLUTION_CONTRACT Verify physical output, reuse and timing/frame semantics.
%   The optimized fixture is used only for reconstruction/validation/reuse;
%   test_pipeline_stages and the recorded public solve start from fresh legs.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
data = load(fullfile(root, 'tests', 'fixtures', 'validated_transfer.mat'));
testCase.TestData.solution = data.solution;
testCase.TestData.problem = data.problem;
options = orb2ds.defaults.numerical_options();
options.output.display = false;
options.solver.run_feasibility = false;
options.solver.max_iterations = 0;
testCase.TestData.options = options;
end

function testIndependentPhysicalValidationAndReconstruction(testCase)
solution = testCase.TestData.solution;
validation = orb2ds.validate_solution(solution, testCase.TestData.problem, testCase.TestData.options);
verifyTrue(testCase, validation.is_feasible);
verifyTrue(testCase, validation.chained.is_feasible);
verifyLessThan(testCase, validation.target_error_km_s, 1e-5);
verifyEqual(testCase, validation.delta_v_m_s, ...
    1000 * sum(vecnorm(solution.nodes.delta_v_km_s, 2, 2)), 'AbsTol', 1e-10);
copy = solution;
trajectory = orb2ds.reconstruct_trajectory(solution, struct('samples_per_segment', 4));
verifyEqual(testCase, solution, copy);
verifyEqual(testCase, numel(trajectory.segments), numel(solution.nodes.time_days) - 1);
verifyLessThan(testCase, max(vecnorm(trajectory.defects(:, 1:3), 2, 2)), 0.001);
end

function testAllFourInitialInformationCases(testCase)
solution = testCase.TestData.solution;
for mode = 1:4
    problem = testCase.TestData.problem;
    if ismember(mode, [2, 4])
        problem.constraints.initial_time_days = solution.nodes.time_days(1);
        problem.constraints.max_wait_time_days = 0;
    end
    if ismember(mode, [3, 4])
        problem.constraints.initial_phase = solution.timing.departure_phase;
        problem.constraints.max_wait_time_days = 0;
    end
    result = orb2ds.optimize_transfer(problem, solution, testCase.TestData.options);
    verifyNotEmpty(testCase, result.solution);
    verifyTrue(testCase, result.validation.is_feasible);
    verifyTrue(testCase, result.validation.checks.timing);
    if mode ~= 1
        verifyEqual(testCase, result.solution.timing.wait_days, 0);
    end
end
end

function testWaitingAndIntersectingCaps(testCase)
solution = testCase.TestData.solution;
problem = testCase.TestData.problem;
wait = 0.1;
solution.timing.wait_days = wait;
problem.constraints.initial_time_days = solution.nodes.time_days(1) - wait;
problem.constraints.initial_phase = mod(solution.timing.departure_phase - ...
    wait / solution.orbit.period_days, 1);
problem.constraints.max_wait_time_days = 0.2;
problem.constraints.max_total_time_days = 30;
result = orb2ds.optimize_transfer(problem, solution, testCase.TestData.options);
verifyNotEmpty(testCase, result.solution);
verifyTrue(testCase, result.validation.checks.timing);
verifyEqual(testCase, result.solution.timing.wait_days, wait, 'AbsTol', 1e-13);
verifyEqual(testCase, result.solution.timing.total_days, ...
    result.solution.timing.transfer_days + wait, 'AbsTol', 1e-12);
end

function testRthUsesActualFinalEpoch(testCase)
solution = testCase.TestData.solution;
problem = testCase.TestData.problem;
geometry = struct('angle_ref_rad', 0.4, 'rate_rad_day', 2 * pi / 365.25);
angle = geometry.angle_ref_rad + geometry.rate_rad_day * solution.nodes.time_days(end);
rotation = [-cos(angle), sin(angle), 0; -sin(angle), -cos(angle), 0; 0, 0, 1];
problem.target = struct('frame', 'earth_sun_rth', ...
    'vinf_km_s', rotation.' * problem.target.vinf_km_s, 'solar_geometry', geometry);
result = orb2ds.optimize_transfer(problem, solution, testCase.TestData.options);
verifyNotEmpty(testCase, result.solution);
verifyLessThan(testCase, result.validation.target_error_km_s, 1e-5);
shifted = solution;
shifted.nodes.time_days = shifted.nodes.time_days + 1;
validation = orb2ds.validate_solution(shifted, problem, testCase.TestData.options);
verifyFalse(testCase, validation.checks.target);
end

function testChangedTargetDiscardsPreviousAcceptance(testCase)
problem = testCase.TestData.problem;
problem.target.vinf_km_s(1) = problem.target.vinf_km_s(1) + 0.02;
result = orb2ds.optimize_transfer(problem, testCase.TestData.solution, testCase.TestData.options);
verifyEmpty(testCase, result.solution);
verifyNotEmpty(testCase, result.candidate);
verifyEqual(testCase, result.status, 'no_validated_solution');
verifyFalse(testCase, result.validation.checks.target);
assert_compact(testCase, result);
end

function testSavingSolutionAlone(testCase)
solution = testCase.TestData.solution;
filename = [tempname '.mat'];
cleanup = onCleanup(@() delete(filename));
save(filename, 'solution');
loaded = load(filename, 'solution');
trajectory = orb2ds.reconstruct_trajectory(loaded.solution, struct('samples_per_segment', 3));
verifyEqual(testCase, numel(trajectory.segments), numel(solution.nodes.time_days) - 1);
assert_compact(testCase, loaded.solution);
end

function assert_compact(testCase, value)
%ASSERT_COMPACT Check that no dense histories, runtime NLPs or callbacks leaked.
verifyFalse(testCase, isa(value, 'function_handle'));
if isstruct(value)
    names = fieldnames(value);
    forbidden = {'trajectory', 'trajectories', 'segments', 'xx', 'tt', 'nlp', ...
        'y_opt', 'constraint_function', 'objective_function'};
    verifyEmpty(testCase, intersect(names, forbidden));
    for element = 1:numel(value)
        for index = 1:numel(names)
            assert_compact(testCase, value(element).(names{index}));
        end
    end
elseif iscell(value)
    for index = 1:numel(value)
        assert_compact(testCase, value{index});
    end
end
end
