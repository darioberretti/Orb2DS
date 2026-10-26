function tests = test_numerical_core
%TEST_NUMERICAL_CORE Check units, derivatives, frames and independent propagation.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
original_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(original_path));
testCase.TestData.model = orb2ds.earth_moon_model();
testCase.TestData.options = orb2ds.defaults.numerical_options();
testCase.TestData.state = [-1.1377073434659586; 0; 0; 0; 1.9863955242330344; 0];
end

function testModelConsistency(testCase)
model = testCase.TestData.model;
verifyEqual(testCase, model.mu, 0.0121506683, 'AbsTol', 1e-16);
verifyEqual(testCase, (86400 * model.time_days)^2, model.distance_km^3 / ...
    (model.gm_earth_km3_s2 + model.gm_moon_km3_s2), 'RelTol', 1e-14);
end

function testForwardBackwardAndClosure(testCase)
model = testCase.TestData.model;
options = testCase.TestData.options;
state = testCase.TestData.state;
final = orb2ds.internal.propagate(state, [0, 0.2], model, options);
back = orb2ds.internal.propagate(final, [0.2, 0], model, options);
verifyLessThan(testCase, norm(back - state), 1e-9);
closed = orb2ds.internal.propagate(state, [0, 3.395596937863704], model, options);
verifyLessThan(testCase, norm(closed - state), 1e-8);
end

function testStateTransition(testCase)
model = testCase.TestData.model;
options = testCase.TestData.options;
state = testCase.TestData.state;
[~, transition] = orb2ds.internal.propagate(state, [0, 0.1], model, options);
numerical = zeros(6);
step = 1e-6;
for index = 1:6
    delta = zeros(6, 1);
    delta(index) = step;
    plus = orb2ds.internal.propagate(state + delta, [0, 0.1], model, options);
    minus = orb2ds.internal.propagate(state - delta, [0, 0.1], model, options);
    numerical(:, index) = (plus - minus) / (2 * step);
end
verifyLessThan(testCase, norm(numerical - transition, 'fro') / norm(transition, 'fro'), 1e-7);
end

function testFramesAndMoonVelocity(testCase)
model = testCase.TestData.model;
states = [10000, 5000, -1000, 0.1, 0.5, -0.2; ...
    40000, -5000, 1000, 0.5, -0.2, 0.1];
eci = orb2ds.internal.frames(states, [2; 7], model, 'to_eci');
back = orb2ds.internal.frames(eci, [2; 7], model, 'to_rotating');
verifyLessThan(testCase, max(abs(back - states), [], 'all'), 1e-9);
moon = [(1 - model.mu) * model.distance_km, 0, 0, 0, 0, 0];
inertial = orb2ds.internal.frames(moon, 0, model, 'to_eci');
verifyEqual(testCase, inertial(5), model.velocity_km_s, 'RelTol', 1e-14);
end

function testLambertIndependentEndpoint(testCase)
gm = 398600.433;
radius = 7000;
duration = 1.5 * pi * sqrt(radius^3 / gm);
[departure, arrival, success] = orb2ds.internal.solve_lambert( ...
    [radius; 0; 0], [0; radius; 0], duration / 86400, gm);
verifyTrue(testCase, success);
rhs = @(~, x) [x(4:6); -gm * x(1:3) / norm(x(1:3))^3];
[~, states] = ode113(rhs, [0, duration], [radius; 0; 0; departure], ...
    odeset('RelTol', 1e-12, 'AbsTol', 1e-12));
verifyLessThan(testCase, norm(states(end, 1:3).' - [0; radius; 0]), 1e-5);
verifyLessThan(testCase, norm(states(end, 4:6).' - arrival), 1e-8);
end

function testSolarTargetDerivative(testCase)
target = struct('vinf_km_s', [2; -1; 0.2], 'frame', 'earth_sun_rth', ...
    'solar_geometry', struct('angle_ref_rad', 0.4, 'rate_rad_day', 2 * pi / 365.25));
[~, derivative] = orb2ds.internal.target_eci(target, 21);
step = 1e-4;
plus = orb2ds.internal.target_eci(target, 21 + step);
minus = orb2ds.internal.target_eci(target, 21 - step);
verifyLessThan(testCase, norm((plus - minus) / (2 * step) - derivative), 1e-10);
end

function testUnknownSettings(testCase)
verifyError(testCase, @() orb2ds.internal.options(struct('n_start', 2)), ...
    'orb2ds:UnknownField');
end
