function tests = test_powered_patching
%TEST_POWERED_PATCHING Check powered hyperbola geometry and shooting guesses.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.restore_path = onCleanup(@() path(old_path));
[problem, options] = orb2ds.load_case(fullfile(root, 'examples', 'config_transfer.m'));
options.output.display = false;
options.patching.n_perigee = 12;
options.patching.n_moon = 18;
testCase.TestData.problem = problem;
testCase.TestData.options = options;
end

function testKnownBallisticLimit(testCase)
gm = 4902.8;
radius = 2200;
speed = 0.8;
a = 1 / (1 + radius * speed^2 / gm);
b = sqrt(1 - a^2);
[cost, ~, r, pre, post] = orb2ds.internal.powered_perilune( ...
    [a, b, 0] * speed, [-a, b, 0] * speed, gm, radius, 65000, 24);
verifyEqual(testCase, norm(r), radius, 'AbsTol', 1e-5);
verifyLessThan(testCase, cost, 3e-7);
verifyEqual(testCase, pre, post, 'AbsTol', 3e-7);
end

function testDifferentAsymptoticSpeeds(testCase)
gm = 4902.8;
incoming = [1.2, 0, 0];
outgoing = [0, 0.6, 0];
[cost, time, r, pre, post] = orb2ds.internal.powered_perilune( ...
    incoming, outgoing, gm, 1900, 65000, 80);
verifyTrue(testCase, isfinite(cost) && cost > 0.05);
verifyGreaterThan(testCase, time, 0);
verifyEqual(testCase, dot(r, pre), 0, 'AbsTol', 1e-7);
verifyEqual(testCase, dot(r, post), 0, 'AbsTol', 1e-7);
verifyEqual(testCase, norm(post - pre), cost, 'AbsTol', 1e-12);
actual = orb2ds.internal.outgoing_asymptote(r, post, gm);
reverse = orb2ds.internal.outgoing_asymptote(r, -pre, gm);
verifyEqual(testCase, actual, outgoing.', 'AbsTol', 1e-10);
verifyEqual(testCase, reverse, -incoming.', 'AbsTol', 1e-10);
invalid = orb2ds.internal.powered_perilune( ...
    [incoming; incoming], [outgoing; incoming], gm, 1900, 65000, 24);
verifyTrue(testCase, isfinite(invalid(1)) && isinf(invalid(2)));
end

function testPoweredGuessThroughPublicStages(testCase)
problem = testCase.TestData.problem;
options = testCase.TestData.options;
options.patching.max_altitude_trials = 1;
options.patching = rmfield(options.patching, 'lunar_flyby_matching_policy');
[candidates, diagnostics] = orb2ds.find_legs(problem, options);
verifyEqual(testCase, diagnostics.settings.lunar_flyby_matching_policy, 'powered');
assertNotEmpty(testCase, candidates);
verifyGreaterThanOrEqual(testCase, diagnostics.powered_pairs_evaluated, numel(candidates));
verifyLessThan(testCase, diagnostics.powered_pairs_evaluated, ...
    options.patching.n_perigee * options.patching.n_moon * diagnostics.departure_replicas);
transfer = [];
for k = 1:numel(candidates)
    transfer = orb2ds.assemble_transfer(rmfield(problem, 'database'), candidates(k), options);
    if ~isempty(transfer)
        break
    end
end
assertNotEmpty(testCase, transfer);
[seed, summary] = orb2ds.mesh_transfer(problem, transfer, options);
verifyEqual(testCase, numel(summary.arcs), 4);
node = seed.events.moon_periapsis_node;
burn = seed.nodes.delta_v_km_s(node, :).';
verifyGreaterThan(testCase, norm(burn), 1e-6);
pre = transfer.arcs(2).initial_state;
post = transfer.arcs(3).initial_state;
verifyEqual(testCase, seed.nodes.state_post(node, :).', post, 'AbsTol', 1e-10);
verifyEqual(testCase, [post(1:3); post(4:6) - burn], pre, 'AbsTol', 1e-10);
patch = transfer.provenance.powered_patch;
verifySize(testCase, patch.soi_defects.position_km, [2, 1]);
verifyLessThan(testCase, patch.soi_defects.position_km(2), 1e-7);
terminal = orb2ds.internal.frames(seed.nodes.state_post(end, :), ...
    seed.nodes.time_days(end), problem.orbit.model, 'to_eci');
achieved = orb2ds.internal.outgoing_asymptote(terminal(1:3), terminal(4:6), ...
    problem.orbit.model.gm_earth_km3_s2);
verifyEqual(testCase, achieved, problem.target.vinf_km_s, 'AbsTol', 1e-7);
nlp = orb2ds.internal.build_nlp(problem, seed, options);
verifyTrue(testCase, nlp.active_impulses(node));

problem.constraints.impulse_nodes = 'endpoints';
options.patching.lunar_flyby_matching_policy = "powered";
verifyError(testCase, @() orb2ds.find_legs(problem, options), 'orb2ds:PoweredFlyby');
end

function testMatchingPolicyDefaultsToNaturalForEndpointOnlyImpulses(testCase)
problem = testCase.TestData.problem;
problem.constraints.impulse_nodes = 'endpoints';
options = testCase.TestData.options;
options.patching = rmfield(options.patching, 'lunar_flyby_matching_policy');
options.output.plot_initial_guess = false;
[seed, search] = orb2ds.build_initial_guess(problem, options);
assertNotEmpty(testCase, seed);
verifyEqual(testCase, search.settings.lunar_flyby_matching_policy, 'natural');
verifyEqual(testCase, seed.nodes.delta_v_km_s(2:end-1, :), ...
    zeros(size(seed.nodes.delta_v_km_s, 1)-2, 3));
end

function testAnchoredRotatingTarget(testCase)
problem = testCase.TestData.problem;
options = testCase.TestData.options;
options.patching.max_altitude_trials = 1;
[candidates, ~] = orb2ds.find_legs(problem, options);
reference = [];
for k = 1:numel(candidates)
    candidate = candidates(k);
    reference = orb2ds.assemble_transfer(problem, candidate, options);
    if ~isempty(reference)
        break
    end
end
assertNotEmpty(testCase, reference);
problem.constraints.initial_time_days = reference.arcs(1).start_days - 0.5;
problem.constraints.max_wait_time_days = 1;
problem.target.frame = 'earth_sun_rth';
problem.target.solar_geometry = struct('angle_ref_rad', 0.4, ...
    'rate_rad_day', 2 * pi / 365.25);
final_time = reference.events.earth_periapsis_days;
angle = 0.4 + 2 * pi / 365.25 * final_time;
rotation = [-cos(angle), sin(angle), 0; -sin(angle), -cos(angle), 0; 0, 0, 1];
problem.target.vinf_km_s = rotation.' * problem.target.vinf_km_s;
candidate.moon_earth.target_epoch_days = final_time;
transfer = orb2ds.assemble_transfer(problem, candidate, options);
assertNotEmpty(testCase, transfer);
seed = orb2ds.mesh_transfer(problem, transfer, options);
assertNotEmpty(testCase, seed);
verifyEqual(testCase, seed.timing.departure_time_days, ...
    problem.constraints.initial_time_days + seed.timing.wait_days, 'AbsTol', 1e-10);
verifyLessThanOrEqual(testCase, seed.timing.wait_days, problem.constraints.max_wait_time_days);
target = orb2ds.internal.target_eci(problem.target, seed.timing.final_time_days);
terminal = orb2ds.internal.frames(seed.nodes.state_post(end, :), ...
    seed.timing.final_time_days, problem.orbit.model, 'to_eci');
achieved = orb2ds.internal.outgoing_asymptote(terminal(1:3), terminal(4:6), ...
    problem.orbit.model.gm_earth_km3_s2);
verifyEqual(testCase, norm(achieved - target), ...
    seed.provenance.seed_screening.target_epoch_error_km_s, 'AbsTol', 1e-8);
verifyLessThan(testCase, norm(achieved - target), 1e-3);
end

function testWeightedSearchAgreesWithExhaustiveRanking(testCase)
problem = testCase.TestData.problem;
problem.constraints.initial_time_days = 3;
problem.constraints.max_wait_time_days = 18;
options = testCase.TestData.options;
options.patching.lunar_impulse_weight = 10;
options.patching.max_altitude_trials = 1;
options.patching.n_perigee = 6;
options.patching.n_moon = 6;
entries = problem.database.encounters;
rows = find(all(isfinite(entries.velocity_infinity_rth_km_s), 2), 24);
for field = string(fieldnames(entries)).'
    problem.database.encounters.(field) = entries.(field)(rows, :);
end
problem.database.encounters.row_id = (1:numel(rows)).';

options.patching.n_candidates = numel(rows) * options.patching.n_perigee * options.patching.n_moon;
exhaustive = orb2ds.find_legs(problem, options);
options.patching.n_candidates = 6;
matches = orb2ds.find_legs(problem, options);
assertGreaterThan(testCase, numel(exhaustive), options.patching.n_candidates);
verifyEqual(testCase, matches, exhaustive(1:options.patching.n_candidates));
rank = [matches.ranking];
verifyEqual(testCase, [rank.powered_score_km_s], [rank.total_delta_v_km_s] + ...
    9 * [rank.lunar_delta_v_km_s], 'AbsTol', 1e-12);

[order, transfers] = orb2ds.internal.rank_powered_guesses(problem, matches, options);
assertNotEmpty(testCase, order);
costs = zeros(size(order));
for k = 1:numel(order)
    transfer = transfers{order(k)};
    lunar = norm(transfer.lunar_impulse_km_s);
    total = norm(transfer.departure_impulse_km_s) + lunar + norm(transfer.terminal_impulse_eci_km_s);
    patch = transfer.provenance.powered_patch;
    verifyEqual(testCase, patch.total_delta_v_km_s, total, 'AbsTol', 1e-12);
    verifyEqual(testCase, patch.ranking_cost_km_s, total + 9 * lunar, 'AbsTol', 1e-12);
    costs(k) = patch.ranking_cost_km_s;
end
verifyTrue(testCase, issorted(costs));
end

function testPoweredStartsFollowAssembledDeltaV(testCase)
problem = testCase.TestData.problem;
problem.constraints.initial_phase = 0.2;
options = testCase.TestData.options;
options.patching.n_perigee = 24;
options.patching.n_moon = 36;
options.patching.max_altitude_trials = 1;
options.patching.n_candidates = 10;
options.n_starts = 2;
defaults = orb2ds.defaults.numerical_options();
options.solver = defaults.solver;
options.solver.run_feasibility = false;
options.solver.max_iterations = 0;
options.solver.display = 'off';
options.output.plot_initial_guess = false;
options.output.plot_nlp_guess = false;
options.validation.require_pass = false;

% Legacy catalogues can repeat an entire physical departure.
candidates = orb2ds.find_legs(problem, options);
entries = problem.database.encounters;
for field = string(fieldnames(entries)).'
    problem.database.encounters.(field) = [entries.(field); entries.(field)];
end
problem.database.encounters.row_id = (1:2*numel(entries.row_id)).';
verifyEqual(testCase, orb2ds.find_legs(problem, options), candidates);

cost = inf(1, numel(candidates));
for index = 1:numel(candidates)
    transfer = orb2ds.assemble_transfer(problem, candidates(index), options);
    if ~isempty(transfer)
        cost(index) = 1000 * (norm(transfer.departure_impulse_km_s) + ...
            norm(transfer.lunar_impulse_km_s) + norm(transfer.terminal_impulse_eci_km_s));
    end
end
[costs, order] = sort(cost);
expected = order(1:options.n_starts);
assertNotEqual(testCase, expected, 1:options.n_starts);
[seed, diagnostics] = orb2ds.build_initial_guess(problem, options);
verifyEqual(testCase, diagnostics.selected_candidate, expected(1));
verifyEqual(testCase, 1000 * sum(vecnorm(seed.nodes.delta_v_km_s, 2, 2)), costs(1), 'AbsTol', 1e-8);

result = orb2ds.find_transfer(problem, options);
verifyEqual(testCase, [result.attempts.candidate_index], expected);
verifyEqual(testCase, [result.attempts.initial_delta_v_m_s], ...
    costs(1:options.n_starts), 'AbsTol', 1e-8);
end
