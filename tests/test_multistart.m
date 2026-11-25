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
options.patching.lunar_flyby_matching_policy = "natural";
options.solver.max_iterations = 0;
options.output.display = false;
options.solver.display = 'off';
options.output.keep_attempt_solutions = true;
options.validation.require_pass = true;
result = orb2ds.find_transfer(problem, options);
verifyNumElements(testCase, result.attempts, 2);
verifyTrue(testCase, all(isfinite([result.attempts.initial_delta_v_m_s])));
verifyTrue(testCase, all(isfinite([result.attempts.solver_max_constraint_violation])));
verifyTrue(testCase, all([result.attempts.transfer_days] > 0));
candidates = orb2ds.find_legs(problem, options);
model = problem.orbit.model;
for attempt = reshape(result.attempts, 1, [])
    transfer = orb2ds.assemble_transfer(problem, candidates(attempt.candidate_index), options);
    epoch = transfer.events.moon_entry_days;
    orbit_entry = orb2ds.internal.evaluate_arc(transfer.arcs(1), epoch, model, options);
    flyby_entry = orb2ds.internal.evaluate_arc(transfer.arcs(2), epoch, model, options);
    expected = hypot(norm(flyby_entry(1:3) - orbit_entry(1:3)) / model.distance_km, ...
        norm(flyby_entry(4:6) - orbit_entry(4:6)) / model.velocity_km_s);
    verifyEqual(testCase, attempt.initial_soi_entry_state_gap_du_vu, expected, 'AbsTol', 1e-12);
end
valid = [result.attempts.is_feasible];
verifyTrue(testCase, any(valid));
verifyNotEmpty(testCase, result.solution);
verifyEqual(testCase, result.solution.metrics.delta_v_m_s, ...
    min([result.attempts(valid).delta_v_m_s]), 'AbsTol', 1e-10);
verifyFalse(testCase, isfield(result.inputs.problem, 'database'));
for index = find(valid)
    verifyNotEmpty(testCase, result.attempts(index).solution);
    verifyFalse(testCase, isfield(result.attempts(index).solution, 'trajectory'));
    verifyEqual(testCase, result.attempts(index).transfer_days, ...
        result.attempts(index).solution.timing.transfer_days);
end
end

function testMeshRefinementSkipsIncompatibleGuesses(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
cleanup = onCleanup(@() path(old_path));
addpath(root);
[problem, options] = orb2ds.load_case(fullfile(root, 'examples', 'config_transfer.m'));
defaults = orb2ds.defaults.numerical_options();
options.output = defaults.output;
options.output.display = false;
options.solver = defaults.solver;
options.solver.run_feasibility = false;
options.solver.max_iterations = 0;
options.patching.lunar_flyby_matching_policy = 'powered';
options.patching.max_altitude_trials = 1;
problem.constraints.initial_phase = 0.2;

% Pick an offset that starts before the first departure but fits a later guess.
candidates = orb2ds.find_legs(problem, options);
[order, transfers] = orb2ds.internal.rank_powered_guesses(problem, candidates, options);
assertNotEmpty(testCase, order);
approach_days = cellfun(@(transfer) transfer.events.moon_periapsis_days - ...
    transfer.arcs(1).start_days, transfers(order));
later = find(approach_days > approach_days(1) + 0.01, 1);
assertNotEmpty(testCase, later);
offset = mean(approach_days([1, later]));
options.mesh.refinement = struct('from', 'moon_periapsis', ...
    'from_offset_days', -offset, 'to', 'earth_periapsis', 'factor', 2);
expected = order(find(approach_days >= offset, 1));
verifyError(testCase, @() orb2ds.mesh_transfer(problem, transfers{order(1)}, options), ...
    'orb2ds:MeshInterval');
[seed, diagnostics] = orb2ds.build_initial_guess(problem, options);
verifyNotEmpty(testCase, seed);
verifyEqual(testCase, diagnostics.selected_candidate, expected);
result = orb2ds.find_transfer(problem, options);
verifyEqual(testCase, [result.attempts.candidate_index], expected);

% If no assembled guess fits, report the same interval error.
options.mesh.refinement.from_offset_days = -max(approach_days) - 1;
verifyError(testCase, @() orb2ds.build_initial_guess(problem, options), 'orb2ds:MeshInterval');
verifyError(testCase, @() orb2ds.find_transfer(problem, options), 'orb2ds:MeshInterval');
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
