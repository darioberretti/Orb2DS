function tests = test_accuracy
%TEST_ACCURACY Verify physical budgets, shared residuals and final acceptance.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
previous = path;
addpath(root);
testCase.TestData.restore = onCleanup(@() path(previous));
testCase.TestData.reference = load(fullfile(root, 'tests', 'fixtures', 'validated_transfer.mat'));
options = orb2ds.defaults.numerical_options();
options.output.display = false;
options.solver.run_feasibility = false;
options.solver.max_iterations = 0;
testCase.TestData.options = options;
end

function testExceptionSwitchInheritanceAndMinimum(testCase)
settings = testCase.TestData.options.accuracy;
settings.dynamics.position_km = 1e-4;
settings.departure.velocity_km_s = 1e-4;
disabled = orb2ds.internal.resolve_accuracy(settings);
verifyEqual(testCase, disabled.dynamics.position_km, settings.position_km);
settings.use_exceptions = true;
enabled = orb2ds.internal.resolve_accuracy(settings);
verifyEqual(testCase, enabled.dynamics.position_km, 1e-4);
verifyEqual(testCase, enabled.departure.velocity_km_s, settings.velocity_km_s);
verifyEqual(testCase, enabled.target.velocity_km_s, settings.velocity_km_s);
verifyEqual(testCase, enabled.clearance.altitude_km, settings.position_km);
end

function testInvalidAccuracyValuesFailBeforeSolving(testCase)
for bad = {0, -1, NaN, Inf, [1, 2]}
    options = testCase.TestData.options;
    options.accuracy.position_km = bad{1};
    verifyTrue(testCase, throws(@() orb2ds.internal.options(options)));
    options = testCase.TestData.options;
    options.accuracy.dynamics.position_km = bad{1};
    verifyTrue(testCase, throws(@() orb2ds.internal.options(options)));
end
options = testCase.TestData.options;
options.accuracy.use_exceptions = 1;
verifyTrue(testCase, throws(@() orb2ds.internal.options(options)));
options = testCase.TestData.options;
options.accuracy.dynamics.unknown = 1;
verifyError(testCase, @() orb2ds.internal.options(options), 'orb2ds:UnknownField');
end

function testPhysicalBudgetsScaleOnlyTheirConstraintBlocks(testCase)
data = testCase.TestData.reference;
options = testCase.TestData.options;
base = orb2ds.internal.build_nlp(data.problem, data.solution, options);
options.accuracy.use_exceptions = true;
options.accuracy.dynamics.position_km = options.accuracy.position_km / 10;
options.accuracy.target.velocity_km_s = options.accuracy.velocity_km_s / 4;
tight = orb2ds.internal.build_nlp(data.problem, data.solution, options);
verifyEqual(testCase, tight.initial, base.initial);
ratio = tight.equality_scale ./ base.equality_scale;
expected = ones(size(ratio));
for index = 1:base.n_nodes - 1
    expected(6 * index + (1:3)) = 10;
end
expected(end - 2:end) = 4;
verifyEqual(testCase, ratio, expected, 'AbsTol', 1e-14);
[c, e, gc, ge] = orb2ds.internal.constraints(base.initial, base);
[tc, te, tgc, tge] = orb2ds.internal.constraints(tight.initial, tight);
verifyEqual(testCase, te, expected .* e, 'AbsTol', 1e-14);
verifyEqual(testCase, full(tge), full(ge * spdiags(expected, 0, numel(e), numel(e))), ...
    'AbsTol', 1e-10);
verifyEqual(testCase, tc, c);
verifyEqual(testCase, tgc, gc);
end

function testVectorBudgetBoundsTheNorm(testCase)
data = testCase.TestData.reference;
nlp = orb2ds.internal.build_nlp(data.problem, data.solution, testCase.TestData.options);
tau = nlp.accuracy.dynamics.position_km;
physical = tau / sqrt(3) * [1; -1; 1];
scaled = physical / nlp.model.distance_km .* nlp.equality_scale(7:9);
verifyEqual(testCase, norm(physical), tau, 'AbsTol', 1e-16);
verifyEqual(testCase, max(abs(scaled)), 1e-9, 'RelTol', 1e-14);
end

function testOutgoingResidualEqualsIndependentHyperbolicAsymptote(testCase)
data = testCase.TestData.reference;
model = data.solution.orbit.model;
nlp = orb2ds.internal.build_nlp(data.problem, data.solution, testCase.TestData.options);
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
last = data.solution.nodes.state_post(end, :).';
last(4:6) = last(4:6) + [1e-4; -2e-4; 1e-4];
time = data.solution.nodes.time_days(end);
[boundary, guard] = orb2ds.internal.terminal_boundary(last ./ scale, time / model.time_days, nlp);
inertial = orb2ds.internal.frames(last.', time, model, 'to_eci');
achieved = orb2ds.internal.outgoing_asymptote(inertial(1:3), inertial(4:6), model.gm_earth_km3_s2);
requested = orb2ds.internal.target_eci(data.problem.target, time);
verifyEqual(testCase, boundary(2:4) * model.velocity_km_s, achieved - requested, 'AbsTol', 1e-11);
verifyLessThan(testCase, guard, 0);
end

function testNonhyperbolicTrialsRemainRealAndEnergyGuardRejectsThem(testCase)
for velocity = {[0; 0; 0], [0; sqrt(0.5); 0], [0.1; 0.1; 0.1]}
    [value, guard] = orb2ds.internal.trial_asymptote([2; 0; 0], velocity{1}, 1, 0.3);
    verifyTrue(testCase, isreal(value) && all(isfinite(value)));
    verifyGreaterThan(testCase, guard, 0);
end
end

function testExceptionsAffectAcceptanceWithoutChangingPhysics(testCase)
data = testCase.TestData.reference;
options = testCase.TestData.options;
base = orb2ds.validate_solution(data.solution, data.problem, options);
verifyTrue(testCase, base.is_feasible);
options.accuracy.dynamics.position_km = base.max_position_defect_km / 2;
disabled = orb2ds.validate_solution(data.solution, data.problem, options);
verifyTrue(testCase, disabled.is_feasible);
options.accuracy.use_exceptions = true;
tight = orb2ds.validate_solution(data.solution, data.problem, options);
verifyFalse(testCase, tight.checks.position_defects);
verifyFalse(testCase, tight.is_feasible);
verifyEqual(testCase, tight.defects, base.defects);
end

function testLocalFeasibilityDoesNotAcceptAChainedFailure(testCase)
data = testCase.TestData.reference;
record = data.solution;
record.nodes.delta_v_km_s(2, 1) = record.nodes.delta_v_km_s(2, 1) + 1e-7;
check = orb2ds.validate_solution(record, data.problem, testCase.TestData.options);
verifyTrue(testCase, check.local_is_feasible);
verifyFalse(testCase, check.chained.is_feasible);
verifyFalse(testCase, check.is_feasible);
verifyFalse(testCase, check.checks.chained);
end

function testSymbolicTrialExtensionAndDerivatives(testCase)
assumeFalse(testCase, isempty(which('casadi.MX')));
x = casadi.MX.sym('trial', 6);
[value, guard] = orb2ds.internal.trial_asymptote(x(1:3), x(4:6), 1, 0.3);
residual = [value; guard];
flow = casadi.Function('escape_test', {x}, {residual, jacobian(residual, x)});
q0 = 0.01 * 0.3^2;
for speed = [0, sqrt(0.5), sqrt(1 + q0) * (1 - 1e-5), sqrt(1 + q0), ...
        sqrt(1 + q0) * (1 + 1e-5), 1.2]
    state = [2; 0; 0; 0; speed; 0];
    [symbolic, derivative] = flow(state);
    [actual, actual_guard] = orb2ds.internal.trial_asymptote(state(1:3), state(4:6), 1, 0.3);
    verifyEqual(testCase, full(symbolic), [actual; actual_guard], 'AbsTol', 1e-12);
    verifyTrue(testCase, all(isfinite(full(derivative)), 'all'));
    numeric = zeros(4, 6);
    for component = 1:6
        trial = state;
        trial(component) = trial(component) + 1i * 1e-20;
        [v, g] = orb2ds.internal.trial_asymptote(trial(1:3), trial(4:6), 1, 0.3);
        numeric(:, component) = imag([v; g]) / 1e-20;
    end
    verifyEqual(testCase, full(derivative), numeric, 'AbsTol', 1e-7, 'RelTol', 1e-10);
end
end

function value = throws(action)
try
    action();
    value = false;
catch
    value = true;
end
end
