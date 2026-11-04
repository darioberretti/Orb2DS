function tests = test_mesh_and_guess
%TEST_MESH_AND_GUESS Verify late-transfer refinement and distinct guess views.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
reference = load(fullfile(root, 'tests', 'fixtures', 'validated_transfer.mat'));
problem = reference.problem;
problem.database = orb2ds.load_orbit_moon_database(fullfile(root, 'data', 'orbit_moon_example.mat'));
options = orb2ds.defaults.numerical_options();
options.output.display = false;
options.patching.n_perigee = 24;
options.patching.n_moon = 36;
options.patching.max_altitude_trials = 8;
candidates = orb2ds.find_legs(problem, options);
transfer = orb2ds.assemble_transfer(problem, candidates(1), options);
assert(~isempty(transfer), 'The reference patch must assemble.');
coarse = orb2ds.mesh_transfer(problem, transfer, options);
options.mesh.refinement.factor = 10;
[seed, summary] = orb2ds.mesh_transfer(problem, transfer, options);
testCase.TestData.problem = problem;
testCase.TestData.options = options;
testCase.TestData.transfer = transfer;
testCase.TestData.seed = seed;
testCase.TestData.coarse = coarse;
testCase.TestData.summary = summary;
end

function testRefinedSpacingContinuesThroughArrival(testCase)
seed = testCase.TestData.seed;
summary = testCase.TestData.summary;
times = seed.nodes.time_days;
refinement = summary.refinement;
verifyGreaterThan(testCase, numel(times), numel(testCase.TestData.coarse.nodes.time_days));
verifyLessThanOrEqual(testCase, max(diff(times)), 0.5 + 1e-12);
selected = times >= refinement.start_days & times <= refinement.end_days;
verifyLessThanOrEqual(testCase, max(diff(times(selected))), 0.05 + 1e-12);
verifyEqual(testCase, times(end), refinement.end_days);
verifyGreaterThan(testCase, refinement.end_days, seed.events.moon_exit_days);
verifyTrue(testCase, any(times == refinement.start_days));
for name = {'moon_entry', 'moon_periapsis', 'moon_exit', 'earth_periapsis'}
    verifyEqual(testCase, times(seed.events.([name{1}, '_node'])), ...
        seed.events.([name{1}, '_days']));
end
verifyEqual(testCase, seed.provenance.mesh, summary);
verifyEqual(testCase, summary.n_nodes, numel(times));
verifyEqual(testCase, summary.arcs(3).n_nodes, ...
    sum(times >= seed.events.moon_exit_days));
end

function testDisabledAndAlternativeEventIntervals(testCase)
options = testCase.TestData.options;
options.mesh.refinement.factor = 1;
disabled = orb2ds.mesh_transfer(testCase.TestData.problem, testCase.TestData.transfer, options);
verifyEqual(testCase, disabled.nodes, testCase.TestData.coarse.nodes);
options.mesh.refinement = struct('from', 'departure', 'from_offset_days', 0, ...
    'to', 'moon_entry', 'factor', 4);
[seed, summary] = orb2ds.mesh_transfer(testCase.TestData.problem, testCase.TestData.transfer, options);
selected = seed.nodes.time_days <= seed.events.moon_entry_days;
verifyLessThanOrEqual(testCase, max(diff(seed.nodes.time_days(selected))), 0.125 + 1e-12);
verifyEqual(testCase, summary.refinement.start_days, seed.nodes.time_days(1));
end

function testInvalidWindowsAndResolutionFailExplicitly(testCase)
options = testCase.TestData.options;
problem = testCase.TestData.problem;
transfer = testCase.TestData.transfer;
options.mesh.refinement.from = 'departure';
verifyError(testCase, @() orb2ds.mesh_transfer(problem, transfer, options), 'orb2ds:MeshInterval');
options.mesh.refinement.from = 'earth_periapsis';
options.mesh.refinement.from_offset_days = 0;
verifyError(testCase, @() orb2ds.mesh_transfer(problem, transfer, options), 'orb2ds:MeshInterval');
options.mesh.refinement = testCase.TestData.options.mesh.refinement;
options.mesh.refinement.factor = 1e9;
verifyError(testCase, @() orb2ds.mesh_transfer(problem, transfer, options), 'orb2ds:MeshResolution');
options = testCase.TestData.options;
options.mesh.refinement.from_offset_days = -1e-8;
verifyError(testCase, @() orb2ds.mesh_transfer(problem, transfer, options), 'orb2ds:MeshResolution');
options = testCase.TestData.options;
options.mesh.n_nodes = 60;
verifyError(testCase, @() orb2ds.internal.options(options), 'orb2ds:UnknownField');
end

function testTranscriptionAppliesTimingBoundsAndImpulsePolicy(testCase)
problem = testCase.TestData.problem;
problem.constraints.initial_time_days = 20;
problem.constraints.initial_phase = 0.4;
problem.constraints.max_wait_time_days = 0.25;
problem.constraints.impulse_nodes = 'endpoints';
seed = testCase.TestData.seed;
seed.timing.wait_days = 10;
seed.nodes.delta_v_km_s(2, :) = [0.001, 0.002, -0.001];
original = seed;
guess = orb2ds.transcribe_guess(problem, seed, testCase.TestData.options);
verifyEqual(testCase, seed, original);
verifyEqual(testCase, guess.timing.wait_days, 0.25, 'AbsTol', 1e-14);
verifyEqual(testCase, guess.nodes.time_days(1), 20.25, 'AbsTol', 1e-12);
verifyEqual(testCase, guess.timing.departure_phase, ...
    0.4 + 0.25 / problem.orbit.period_days, 'AbsTol', 1e-14);
verifyEqual(testCase, guess.nodes.delta_v_km_s(2:end - 1, :), ...
    zeros(numel(seed.nodes.time_days) - 2, 3));
verifyNumElements(testCase, guess.nodes.time_days, numel(seed.nodes.time_days));
verifyFalse(testCase, isfield(guess, 'nlp') || isfield(guess, 'trajectory'));
end

function testAssembledLegsAndMeshMarkerInBothFrames(testCase)
transfer = testCase.TestData.transfer;
seed = testCase.TestData.seed;
original = seed;
for frame = {'rotating', 'eci'}
    figure_handle = orb2ds.plot_initial_guess(transfer, seed, ...
        struct('visible', 'off', 'frame', frame{1}, 'samples_per_arc', 12));
    cleanup = onCleanup(@() close(figure_handle));
    for label = {'Orbit-Moon leg', 'Lunar flyby', 'Moon-Earth leg'}
        verifyNumElements(testCase, findobj(figure_handle, 'DisplayName', label{1}), 1);
    end
    marker = findobj(figure_handle, 'DisplayName', 'Refinement start');
    verifyNumElements(testCase, marker, 1);
    time = seed.provenance.mesh.refinement.start_days;
    index = find(seed.nodes.time_days == time, 1);
    position = seed.nodes.state_post(index, 1:3);
    if strcmp(frame{1}, 'rotating')
        position = position / seed.orbit.model.distance_km;
    else
        model = seed.orbit.model;
        angle = model.moon_angle_ref_rad + time / model.time_days;
        position = position + [model.mu * model.distance_km, 0, 0];
        position = [cos(angle) * position(1) - sin(angle) * position(2), ...
            sin(angle) * position(1) + cos(angle) * position(2), position(3)];
    end
    verifyEqual(testCase, [marker.XData, marker.YData, marker.ZData], position, 'AbsTol', 1e-9);
    verifyEqual(testCase, seed, original);
end
end

function testAssembledPlotWithoutMesh(testCase)
figure_handle = orb2ds.plot_initial_guess(testCase.TestData.transfer, [], ...
    struct('visible', 'off', 'samples_per_arc', 8));
cleanup = onCleanup(@() close(figure_handle));
verifyEmpty(testCase, findobj(figure_handle, 'DisplayName', 'Shooting nodes'));
verifyEmpty(testCase, findobj(figure_handle, 'DisplayName', 'Refinement start'));
verifyEqual(testCase, figure_handle.Name, 'Assembled initial guess');
verifyNumElements(testCase, findobj(figure_handle, 'DisplayName', 'Moon-Earth leg'), 1);
end

function testTranscribedDefectLinesShowActualPropagatedEnds(testCase)
guess = orb2ds.transcribe_guess(testCase.TestData.problem, ...
    testCase.TestData.seed, testCase.TestData.options);
trajectory = orb2ds.reconstruct_trajectory(guess, struct('samples_per_segment', 4));
figure_handle = orb2ds.plot_trajectory(trajectory, struct('visible', 'off', 'show_defects', true));
cleanup = onCleanup(@() close(figure_handle));
lines = findall(figure_handle, 'DisplayName', 'Position defects');
verifyNumElements(testCase, lines, numel(trajectory.segments));
expected = zeros(numel(trajectory.segments), 1);
for index = 1:numel(expected)
    expected(index) = norm(trajectory.defects(index, 1:3)) / trajectory.model.distance_km;
end
actual = arrayfun(@(line) norm([diff(line.XData), diff(line.YData), diff(line.ZData)]), lines);
verifyEqual(testCase, sort(actual(:)), sort(expected), 'AbsTol', 1e-13);
end

function testAutomaticPreviewsDoNotChangeSolverInputs(testCase)
problem = testCase.TestData.problem;
options = testCase.TestData.options;
options.output.display = false;
options.solver.run_feasibility = false;
options.solver.max_iterations = 0;
quiet = orb2ds.find_transfer(problem, options);
before = findall(groot, 'Type', 'figure');
visibility = get(groot, 'DefaultFigureVisible');
restore = onCleanup(@() set(groot, 'DefaultFigureVisible', visibility));
set(groot, 'DefaultFigureVisible', 'off');
options.output.plot_nlp_guess = true;
options.output.plot_initial_guess = true;
shown = orb2ds.find_transfer(problem, options);
created = setdiff(findall(groot, 'Type', 'figure'), before);
cleanup = onCleanup(@() close(created));
verifyNumElements(testCase, created, 2);
verifyTrue(testCase, any(strcmp({created.Name}, 'NLP-transcribed initial guess')));
verifyTrue(testCase, any(contains({created.Name}, 'Assembled initial guess')));
assembled = created(contains({created.Name}, 'Assembled initial guess'));
nlp_plot = created(strcmp({created.Name}, 'NLP-transcribed initial guess'));
verifyEmpty(testCase, findobj(assembled, 'DisplayName', 'Shooting nodes'));
verifyNumElements(testCase, findobj(nlp_plot, 'DisplayName', 'Shooting nodes'), 1);
verifyEqual(testCase, shown.solution, quiet.solution);
verifyEqual(testCase, shown.candidate, quiet.candidate);
verifyEqual(testCase, shown.seed, quiet.seed);
verifyEqual(testCase, shown.validation, quiet.validation);
verifyFalse(testCase, isfield(shown, 'trajectory') || isfield(shown, 'figures'));
end
