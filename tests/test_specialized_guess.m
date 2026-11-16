function tests = test_specialized_guess
%TEST_SPECIALIZED_GUESS Exercise configured database-to-NLP guess construction.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
database = orb2ds.load_orbit_moon_database(fullfile(root, 'data', 'orbit_moon_example.mat'));
problem = struct('orbit', database.orbit, 'database', database, ...
    'target', struct('frame', 'eci', ...
    'vinf_km_s', [-2.0511679723998526; 1.4213996556899797; -0.1575143883070597]), ...
    'constraints', struct('max_transfer_time_days', 50, ...
    'min_earth_altitude_km', 1000, 'min_moon_altitude_km', 100));
options = orb2ds.defaults.numerical_options();
options.output.display = false;
options.patching.n_perigee = 24;
options.patching.n_moon = 36;
options.patching.max_altitude_trials = 8;
options.mesh.max_step_days = 1;
testCase.TestData.problem = problem;
testCase.TestData.options = options;
end

function testSevenInitialEventConfigurations(testCase)
% Each case starts from database encounters, never from an optimized result.
configurations = [false, false, false; true, false, false; false, true, false; ...
    true, true, false; true, false, true; false, true, true; true, true, true];
for index = 1:size(configurations, 1)
    problem = configured_problem(testCase.TestData.problem, configurations(index, :));
    [seed, search] = orb2ds.build_initial_guess(problem, testCase.TestData.options);
    verifyNotEmpty(testCase, seed);
    check_boundaries(testCase, problem, seed);
    verifyTrue(testCase, seed.provenance.seed_screening.meets_time_caps);
    verifyLessThanOrEqual(testCase, seed.timing.transfer_days, 50);
    if index == 1
        verifyEqual(testCase, seed.provenance.database_row, 764);
        verifyEqual(testCase, seed.timing.departure_phase, 1 / 3, 'AbsTol', 1e-12);
        verifyEqual(testCase, seed.timing.transfer_days, 22.262762, 'AbsTol', 1e-5);
        verifyLessThan(testCase, seed.nodes.time_days(1), 0);
    end
    if configurations(index, 1) && ~configurations(index, 3)
        grid = unique(problem.database.encounters.departure_phase);
        distance = abs(mod(grid - 0.413 + 0.5, 1) - 0.5);
        [~, order] = sort(distance);
        verifyEqual(testCase, search.departure_phase_grid, sort(grid(order(1:2))));
    end
    if configurations(index, 3)
        verifyLessThanOrEqual(testCase, seed.timing.wait_days, 18);
        verifyLessThanOrEqual(testCase, seed.timing.total_days, 55);
    end
    if index == 5 || index == 7
        verifyGreaterThan(testCase, seed.timing.wait_days, 0);
        row = seed.provenance.database_row;
        verifyEqual(testCase, seed.timing.departure_phase, ...
            problem.database.encounters.departure_phase(row), 'AbsTol', 1e-12);
    end
end
end

function testRthTargetUsesReconstructedArrivalEpoch(testCase)
for anchored = [false, true]
    problem = configured_problem(testCase.TestData.problem, [anchored, anchored, anchored]);
    problem.target.frame = 'earth_sun_rth';
    problem.target.solar_geometry = struct('angle_ref_rad', 0.4, ...
        'rate_rad_day', 2 * pi / 365.25);
    angle = 0.4 + 2 * pi / 365.25 * 42;
    matrix = [-cos(angle), sin(angle), 0; -sin(angle), -cos(angle), 0; 0, 0, 1];
    problem.target.vinf_km_s = matrix.' * testCase.TestData.problem.target.vinf_km_s;
    seed = orb2ds.build_initial_guess(problem, testCase.TestData.options);
    verifyNotEmpty(testCase, seed);
    check_boundaries(testCase, problem, seed);
    target = orb2ds.internal.target_eci(problem.target, seed.nodes.time_days(end));
    at_zero = orb2ds.internal.target_eci(problem.target, 0);
    verifyGreaterThan(testCase, norm(target - at_zero), 0.01);
    verifyLessThan(testCase, seed.provenance.seed_screening.target_epoch_error_km_s, 1e-7);
end
end

function testOffGridPhaseKeepsCatalogueDepartureForBothMatchers(testCase)
problem = configured_problem(testCase.TestData.problem, [true, false, false]);
options = testCase.TestData.options;
for method = {'ballistic', 'powered'}
    options.patching.method = method{1};
    seed = orb2ds.build_initial_guess(problem, options);
    assertNotEmpty(testCase, seed);
    check_boundaries(testCase, problem, seed);
    verifyNotEqual(testCase, seed.timing.departure_phase, problem.constraints.initial_phase);
    nlp = orb2ds.internal.build_nlp(problem, seed, options);
    [~, equality] = orb2ds.internal.constraints(nlp.initial, nlp);
    verifyGreaterThan(testCase, norm(equality(1:3)), 0);
end
end

function testOverCapGuessDoesNotRelaxProblem(testCase)
problem = configured_problem(testCase.TestData.problem, [true, true, false]);
problem.constraints.max_transfer_time_days = 0.1;
problem.constraints.max_total_time_days = 0.2;
seed = orb2ds.build_initial_guess(problem, testCase.TestData.options);
verifyNotEmpty(testCase, seed);
verifyFalse(testCase, seed.provenance.seed_screening.meets_time_caps);
verifyGreaterThan(testCase, seed.provenance.seed_screening.time_excess_days, 1);
nlp = orb2ds.internal.build_nlp(problem, seed, testCase.TestData.options);
verifyEqual(testCase, nlp.problem.constraints, problem.constraints);
verifyGreaterThan(testCase, max(nlp.A * nlp.initial - nlp.b), 0);
verifyEqual(testCase, seed.timing.wait_days, 0);
end

function testFixedEpochBallisticEarthLegStartsAtLunarExit(testCase)
problem = configured_problem(testCase.TestData.problem, [false, true, false]);
options = testCase.TestData.options;
[seed, search] = orb2ds.build_initial_guess(problem, options);
assertNotEmpty(testCase, seed);
candidates = orb2ds.find_legs(problem, options);
transfer = orb2ds.assemble_transfer(problem, candidates(search.selected_candidate), options);
exit = transfer.events.moon_exit_days;
verifyEqual(testCase, transfer.arcs(3).initial_days, exit);
lunar = orb2ds.internal.evaluate_arc(transfer.arcs(2), exit, problem.orbit.model, options);
earth = orb2ds.internal.evaluate_arc(transfer.arcs(3), exit, problem.orbit.model, options);
verifyLessThan(testCase, norm(lunar(1:3) - earth(1:3)), 1e-6);
verifyEqual(testCase, seed.nodes.delta_v_km_s(2:end-1, :), zeros(numel(seed.nodes.time_days)-2, 3));
check_boundaries(testCase, problem, seed);
end

function testOmittedEmptyAndZeroWaitProduceTheSameGuess(testCase)
options = testCase.TestData.options;
base = configured_problem(testCase.TestData.problem, [true, true, false]);
reference = [];
for representation = 1:3
    problem = base;
    if representation == 1
        problem.constraints = rmfield(problem.constraints, 'max_wait_time_days');
    elseif representation == 2
        problem.constraints.max_wait_time_days = [];
    end
    seed = orb2ds.build_initial_guess(problem, options);
    assertNotEmpty(testCase, seed);
    check_boundaries(testCase, problem, seed);
    verifyEqual(testCase, seed.timing.wait_days, 0);
    nlp = orb2ds.internal.build_nlp(problem, seed, options);
    verifyEqual(testCase, nlp.problem.constraints.max_wait_time_days, 0);
    verifyEqual(testCase, nlp.lower(nlp.wait_index), 0);
    verifyEqual(testCase, nlp.upper(nlp.wait_index), 0);
    if isempty(reference)
        reference = seed;
    else
        verifyEqual(testCase, seed.nodes, reference.nodes);
        verifyEqual(testCase, seed.timing, reference.timing);
    end
end

% Without an initial event, even a positive wait cap adds no waiting variable.
problem = testCase.TestData.problem;
problem.constraints.max_wait_time_days = 40;
seed = orb2ds.build_initial_guess(problem, options);
nlp = orb2ds.internal.build_nlp(problem, seed, options);
verifyNotEmpty(testCase, nlp.phase_index);
verifyNotEmpty(testCase, nlp.epoch_index);
verifyEmpty(testCase, nlp.wait_index);
verifyEqual(testCase, seed.timing.wait_days, 0);
verifyEqual(testCase, seed.timing.total_days, seed.timing.transfer_days);
end

function testInvalidWaitingLimitsFailBeforeMatching(testCase)
problem = testCase.TestData.problem;
invalid = {-1, Inf, -Inf, NaN, [1, 2], 1i, '3', true, '', struct()};
for index = 1:numel(invalid)
    problem.constraints.max_wait_time_days = invalid{index};
    verifyError(testCase, @() orb2ds.build_initial_guess(problem, ...
        testCase.TestData.options), 'orb2ds:WaitTime');
end
end

function testWaitingReplicaEnumerationUsesTheEntireWaitCap(testCase)
problem = configured_problem(testCase.TestData.problem, [true, true, true]);
problem.constraints.initial_phase = 0.25;
period = problem.orbit.period_days;
problem.constraints.max_wait_time_days = 3.5 * period;
entries = struct('departure_phase', 0.5);
departures = orb2ds.internal.seed_departures(problem, entries);
positive_waits = departures.wait_days(departures.wait_days > 0);
verifyEqual(testCase, positive_waits, (0.25 + (0:3).') * period, 'AbsTol', 1e-12);
verifyEqual(testCase, departures.phase(departures.wait_days > 0), repmat(0.5, 4, 1));
end

function testPrescribedGeometryBatches(testCase)
problem = testCase.TestData.problem;
problem.constraints.initial_time_days = 0;
problem.constraints.max_wait_time_days = 0;
model = problem.orbit.model;
samples = [0.25; 2; 4; 0.25 + 2*pi];
inbound = [0.15; 2.4; 4.1; 2*pi-0.05; 2*pi+2.1];
duration = (inbound - model.moon_angle_ref_rad) * model.time_days;
departures.wait_days = zeros(size(duration));

% Match the reference circular assignment, including the wrap to phase zero.
[earth, first, last] = orb2ds.internal.encounter_batches(problem, departures, duration, samples);
verifyEqual(testCase, first, earth([1; 2; 3; 1; 2]));
verifyEqual(testCase, last, first);

% A repeating lunar angle belongs to a distinct epoch for an RTH target.
problem.target.frame = 'earth_sun_rth';
[earth, first, last] = orb2ds.internal.encounter_batches(problem, departures, duration, samples);
verifyEqual(testCase, first, earth([1; 2; 3; 4; 4]));
verifyEqual(testCase, last, first);
problem.constraints.max_wait_time_days = 30;
timing = orb2ds.internal.seed_timing(problem, [-0.5; 29], [0; 0], [0; 0], [5; 5]);
verifyEqual(testCase, timing.wait_days, [0; 29]);

% With free phase, an allowed wait can reach the next batch across the seam.
problem.target.frame = 'eci';
problem.constraints.max_wait_time_days = 1.4 * model.time_days;
[earth, first, last] = orb2ds.internal.encounter_batches(problem, departures, duration, samples(1:3));
verifyEqual(testCase, first(3), earth(3));
verifyEqual(testCase, last(3), numel(earth) + earth(1));

% A prescribed spacecraft phase supplies discrete wait replicas instead.
problem.constraints.initial_phase = 0.25;
departures.wait_days(3) = 1.4 * model.time_days;
[earth, first, last] = orb2ds.internal.encounter_batches(problem, departures, duration, samples(1:3));
verifyEqual(testCase, first(3), earth(1));
verifyEqual(testCase, last, first);
end

function testDayThreePoweredGuess(testCase)
problem = testCase.TestData.problem;
problem.constraints.initial_time_days = 3;
problem.target.vinf_km_s = 2 * problem.target.vinf_km_s;
options = testCase.TestData.options;
options.patching.method = 'powered';
options.patching.max_altitude_trials = 1;
[seed, search] = orb2ds.build_initial_guess(problem, options);
assertNotEmpty(testCase, seed);
verifyEqual(testCase, search.candidate_counts, options.patching.n_candidates);
check_boundaries(testCase, problem, seed);
end

function problem = configured_problem(problem, flags)
%CONFIGURED_PROBLEM Specify phase, epoch and permission to wait independently.
if flags(1)
    problem.constraints.initial_phase = 0.413;
end
if flags(2)
    problem.constraints.initial_time_days = 20;
end
if flags(3)
    problem.constraints.max_wait_time_days = 18;
    problem.constraints.max_total_time_days = 55;
else
    problem.constraints.max_wait_time_days = 0;
end
end

function check_boundaries(testCase, problem, seed)
%CHECK_BOUNDARIES Independently check orbit departure, target and transcription.
options = testCase.TestData.options;
model = problem.orbit.model;
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
state = orb2ds.internal.propagate(problem.orbit.state_ref ./ scale, ...
    [0, seed.timing.departure_phase * problem.orbit.period_days / model.time_days], ...
    model, options) .* scale;
state(4:6) = state(4:6) + seed.nodes.delta_v_km_s(1, :).';
verifyEqual(testCase, seed.nodes.state_post(1, :).', state, 'AbsTol', 1e-7);
if isfield(problem.constraints, 'initial_time_days')
    verifyEqual(testCase, seed.nodes.time_days(1), ...
        problem.constraints.initial_time_days + seed.timing.wait_days, 'AbsTol', 1e-10);
end
if isfield(problem.constraints, 'initial_phase')
    verifyEqual(testCase, seed.timing.departure_phase, ...
        seed.provenance.database_departure_phase, 'AbsTol', 1e-12);
end
terminal = orb2ds.internal.frames(seed.nodes.state_post(end, :), ...
    seed.nodes.time_days(end), model, 'to_eci');
achieved = orb2ds.internal.outgoing_asymptote(terminal(1:3), terminal(4:6), ...
    model.gm_earth_km3_s2);
target = orb2ds.internal.target_eci(problem.target, seed.nodes.time_days(end));
verifyLessThan(testCase, norm(achieved - target), 1e-6);
transcribed = orb2ds.transcribe_guess(problem, seed, options);
verifyEqual(testCase, transcribed.nodes.time_days, seed.nodes.time_days, 'AbsTol', 1e-10);
verifyEqual(testCase, transcribed.nodes.state_post, seed.nodes.state_post, 'AbsTol', 1e-7);
if isfield(problem.constraints, 'initial_phase')
    verifyEqual(testCase, transcribed.timing.departure_phase, ...
        mod(problem.constraints.initial_phase + seed.timing.wait_days / ...
        problem.orbit.period_days, 1), 'AbsTol', 1e-12);
end
verifyEqual(testCase, seed.timing.total_days, ...
    seed.timing.wait_days + seed.timing.transfer_days, 'AbsTol', 1e-10);
end
