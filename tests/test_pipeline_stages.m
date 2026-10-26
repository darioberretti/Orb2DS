function tests = test_pipeline_stages
%TEST_PIPELINE_STAGES Check fresh matching/assembly without an optimized seed.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
[problem, options] = orb2ds.load_case(fullfile(root, 'examples', 'config_example.m'));
options.output.display = false;
[candidates, diagnostics] = orb2ds.find_legs(problem, options);
assert(~isempty(candidates), 'The canonical example search must return candidates.');
transfer = [];
for index = 1:numel(candidates)
    transfer = orb2ds.assemble_transfer(problem, candidates(index), options);
    if ~isempty(transfer)
        break
    end
end
assert(~isempty(transfer), 'No candidate produced a finite assembled passage.');
testCase.TestData.problem = problem;
testCase.TestData.options = options;
testCase.TestData.candidates = candidates;
testCase.TestData.diagnostics = diagnostics;
testCase.TestData.transfer = transfer;
end

function testRankingAndSelfContainedAssembly(testCase)
candidates = testCase.TestData.candidates;
costs = arrayfun(@(candidate) candidate.ranking.earth_delta_v_km_s, candidates);
verifyTrue(testCase, all(diff(costs) >= 0));
problem = rmfield(testCase.TestData.problem, 'database');
transfer = orb2ds.assemble_transfer(problem, candidates(1), testCase.TestData.options);
verifyNotEmpty(testCase, transfer);
verifyFalse(testCase, isfield(transfer, 'database'));
verifyFalse(testCase, isfield(transfer, 'trajectory'));
events = transfer.events;
verifyLessThan(testCase, events.moon_entry_days, events.moon_periapsis_days);
verifyLessThan(testCase, events.moon_periapsis_days, events.moon_exit_days);
verifyLessThan(testCase, events.moon_exit_days, events.earth_periapsis_days);
end

function testMeshAndIndependentTerminalGeometry(testCase)
problem = rmfield(testCase.TestData.problem, 'database');
seed = orb2ds.mesh_transfer(problem, testCase.TestData.transfer, testCase.TestData.options);
verifyTrue(testCase, all(diff(seed.nodes.time_days) > 0));
verifyEqual(testCase, seed.nodes.time_days(seed.events.moon_periapsis_node), ...
    seed.events.moon_periapsis_days, 'AbsTol', 1e-12);
terminal = orb2ds.internal.frames(seed.nodes.state_post(end, :), ...
    seed.nodes.time_days(end), problem.orbit.model, 'to_eci');
achieved = orb2ds.internal.outgoing_asymptote(terminal(1:3), terminal(4:6), ...
    problem.orbit.model.gm_earth_km3_s2);
verifyLessThan(testCase, norm(achieved - problem.target.vinf_km_s), 1e-5);
verifyEqual(testCase, seed.nodes.delta_v_km_s(2:end - 1, :), ...
    zeros(size(seed.nodes.delta_v_km_s, 1) - 2, 3));
end

function testEmptySearchIsNotAnInputError(testCase)
problem = testCase.TestData.problem;
names = fieldnames(problem.database.encounters);
for index = 1:numel(names)
    matrix = problem.database.encounters.(names{index});
    problem.database.encounters.(names{index}) = matrix([], :);
end
result = orb2ds.find_transfer(problem, testCase.TestData.options);
verifyEqual(testCase, result.status, 'no_seed_found');
verifyEmpty(testCase, result.solution);
verifyEmpty(testCase, result.attempts);
verifyEqual(testCase, result.search.reason, 'no_hyperbolic_encounters_in_database');
end

function testUnsupportedAndIncompatibleRequests(testCase)
problem = testCase.TestData.problem;
problem.constraints.final_time_days = [40, 50];
verifyError(testCase, @() orb2ds.find_legs(problem, testCase.TestData.options), 'orb2ds:Unsupported');
problem = testCase.TestData.problem;
problem.orbit.period_days = problem.orbit.period_days + 0.01;
verifyError(testCase, @() orb2ds.find_legs(problem, testCase.TestData.options), 'orb2ds:OrbitMismatch');
end
