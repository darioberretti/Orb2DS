function tests = test_nlp_contract
%TEST_NLP_CONTRACT Verify normalization, Oshima impulses and timing sensitivities.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
model = orb2ds.earth_moon_model();
options = orb2ds.defaults.numerical_options();
scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
reference = [-1.1377073434659586; 0; 0; 0; 1.9863955242330344; 0];
orbit = struct('schema_version', 1, 'state_ref', reference .* scale.', ...
    'period_days', 3.395596937863704 * model.time_days, 'model', model);
states = zeros(3, 6);
states(1, :) = orb2ds.internal.propagate(reference, [0, 0.2 * 3.395596937863704], ...
    model, options).';
for index = 2:3
    states(index, :) = orb2ds.internal.propagate(states(index - 1, :).', ...
        [0, 0.03], model, options).';
end
impulses = [0.01, -0.005, 0.003; -0.001, 0.002, 0; -0.02, 0, 0];
states(:, 4:6) = states(:, 4:6) + impulses / model.velocity_km_s;
seed = struct('schema_version', 1, 'orbit', orbit, ...
    'nodes', struct('time_days', [2; 2.03; 2.06] * model.time_days, ...
    'state_post', states .* scale, 'delta_v_km_s', impulses), ...
    'events', struct('moon_periapsis_node', 2), ...
    'timing', struct('departure_phase', 0.2), 'integration', options.integration, ...
    'provenance', struct());
problem = struct('orbit', orbit, 'target', struct('frame', 'earth_sun_rth', ...
    'vinf_km_s', [2; -1; 0.1], 'solar_geometry', ...
    struct('angle_ref_rad', 0.4, 'rate_rad_day', 2 * pi / 365.25)), ...
    'constraints', struct());
testCase.TestData.seed = seed;
testCase.TestData.problem = problem;
testCase.TestData.options = options;
end

function testImpulseMapsAndCost(testCase)
impulses = [1, 2, 3; -1, 0, 0; -0.01, 0.03, -0.1; 0, 0, 0];
[u, swapped] = orb2ds.internal.regularize_impulses(impulses);
for index = 1:size(u, 1)
    reconstructed = orb2ds.internal.impulse_map(u(index, :), swapped(index));
    verifyEqual(testCase, reconstructed, impulses(index, :).', 'AbsTol', 1e-13);
    verifyEqual(testCase, sum(u(index, :).^2), norm(impulses(index, :)), 'AbsTol', 1e-13);
end
nlp = orb2ds.internal.build_nlp(testCase.TestData.problem, ...
    testCase.TestData.seed, testCase.TestData.options);
[cost, gradient] = orb2ds.internal.objective(nlp.initial, nlp);
expected = sum(vecnorm(testCase.TestData.seed.nodes.delta_v_km_s, 2, 2));
verifyEqual(testCase, cost * nlp.model.velocity_km_s, expected, 'AbsTol', 1e-13);
verifyTrue(testCase, all(isfinite(gradient)));
end

function testAllIndependentGradients(testCase)
nlp = orb2ds.internal.build_nlp(testCase.TestData.problem, ...
    testCase.TestData.seed, testCase.TestData.options);
check_derivatives(testCase, nlp, 1:nlp.n_variables);
end

function testTiedEpochPhaseAndWaitGradients(testCase)
problem = testCase.TestData.problem;
problem.constraints = struct('initial_time_days', 4, 'initial_phase', 0.17, ...
    'max_wait_time_days', 3, 'max_transfer_time_days', 10, 'max_total_time_days', 11);
nlp = orb2ds.internal.build_nlp(problem, testCase.TestData.seed, testCase.TestData.options);
nlp.initial(nlp.wait_index) = 0.3;
decoded = orb2ds.internal.decode_nlp(nlp.initial, nlp);
verifyEqual(testCase, decoded.departure_epoch, 4 / nlp.model.time_days + 0.3, 'AbsTol', 1e-14);
verifyEqual(testCase, decoded.phase, 0.17 + 0.3 / nlp.period_tu, 'AbsTol', 1e-14);
verifyEmpty(testCase, nlp.epoch_index);
verifyEmpty(testCase, nlp.phase_index);
verifySize(testCase, nlp.A, [2, nlp.n_variables]);
check_derivatives(testCase, nlp, [nlp.wait_index, nlp.duration_indices, 10:15, 19:24]);
end

function testFreeDefaultsAndEndpointPolicy(testCase)
problem = testCase.TestData.problem;
nlp = orb2ds.internal.build_nlp(problem, testCase.TestData.seed, testCase.TestData.options);
verifyNotEmpty(testCase, nlp.phase_index);
verifyNotEmpty(testCase, nlp.epoch_index);
verifyEmpty(testCase, nlp.wait_index);
verifyEmpty(testCase, nlp.A);
problem.constraints.impulse_nodes = 'endpoints';
restricted = orb2ds.internal.build_nlp(problem, testCase.TestData.seed, testCase.TestData.options);
verifyEqual(testCase, restricted.lower(16:18), zeros(3, 1));
verifyEqual(testCase, restricted.upper(16:18), zeros(3, 1));
end

function testSingleKnownInitialQuantity(testCase)
for name = {'initial_phase', 'initial_time_days'}
    problem = testCase.TestData.problem;
    problem.constraints.(name{1}) = 0.17;
    nlp = orb2ds.internal.build_nlp(problem, testCase.TestData.seed, testCase.TestData.options);
    nlp.initial(nlp.wait_index) = 0.3;
    columns = [nlp.phase_index, nlp.epoch_index, nlp.wait_index, nlp.duration_indices];
    check_derivatives(testCase, nlp, columns);
end
end

function testEquivalentCapsAndTimeResolution(testCase)
problem = testCase.TestData.problem;
problem.constraints = struct('max_transfer_time_days', 10, 'max_total_time_days', 9);
nlp = orb2ds.internal.build_nlp(problem, testCase.TestData.seed, testCase.TestData.options);
verifySize(testCase, nlp.A, [1, nlp.n_variables]);
verifyEqual(testCase, nlp.b, 9 / nlp.model.time_days);
minimum = nlp.initial;
minimum(nlp.duration_indices) = nlp.lower(nlp.duration_indices);
decoded = orb2ds.internal.decode_nlp(minimum, nlp);
verifyTrue(testCase, all(diff(decoded.times) > 0));
end

function check_derivatives(testCase, nlp, columns)
%CHECK_DERIVATIVES Compare the full constraint Jacobians with independent differences.
vector = nlp.initial;
[c, ceq, gc, geq] = orb2ds.internal.constraints(vector, nlp);
numeric_c = zeros(numel(c), numel(columns));
numeric_eq = zeros(numel(ceq), numel(columns));
step = 1e-6;
for index = 1:numel(columns)
    perturbation = zeros(size(vector));
    perturbation(columns(index)) = step;
    [plus_c, plus_eq] = orb2ds.internal.constraints(vector + perturbation, nlp);
    [minus_c, minus_eq] = orb2ds.internal.constraints(vector - perturbation, nlp);
    numeric_c(:, index) = (plus_c - minus_c) / (2 * step);
    numeric_eq(:, index) = (plus_eq - minus_eq) / (2 * step);
end
error_c = norm(full(gc(columns, :).') - numeric_c, 'fro') / max(1, norm(numeric_c, 'fro'));
error_eq = norm(full(geq(columns, :).') - numeric_eq, 'fro') / max(1, norm(numeric_eq, 'fro'));
verifyLessThan(testCase, error_c, 1e-6);
verifyLessThan(testCase, error_eq, 1e-6);
end
