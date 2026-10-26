function tests = test_presentation
%TEST_PRESENTATION Check physical plotting transforms and independent display controls.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
model = orb2ds.earth_moon_model(struct('moon_angle_ref_rad', 0.4));
states = [0.2, 0.1, 0.04; 0.3, -0.2, 0.08; -0.4, 0.3, -0.02] * model.distance_km;
states(:, 4:6) = 0;
times = [0; pi / 2; pi] * model.time_days;
trajectory = struct('model', model, 'nodes', struct('state_post', states, ...
    'time_days', times, 'delta_v_km_s', [1, 2, 3; -2, 1, 0; 0, 0, 0] / 100));
trajectory.segments = {struct('state', states(1:2, :), 'time_days', times(1:2)); ...
    struct('state', states(2:3, :), 'time_days', times(2:3))};
testCase.TestData.trajectory = trajectory;
data = load(fullfile(root, 'tests', 'fixtures', 'validated_transfer.mat'));
testCase.TestData.solution = data.solution;
testCase.TestData.problem = data.problem;
options = orb2ds.defaults.numerical_options();
options.solver.max_iterations = 0;
options.solver.max_iterations_feasibility = 0;
options.output.display = false;
testCase.TestData.options = options;
end

function testRotatingUnitsAndRelativeBurnVectors(testCase)
trajectory = testCase.TestData.trajectory;
original = trajectory;
figure_handle = orb2ds.plot_trajectory(trajectory, struct('visible', 'off'));
cleanup = onCleanup(@() close(figure_handle));
nodes = findobj(figure_handle, 'DisplayName', 'Shooting nodes');
verifyEqual(testCase, nodes.XData(:), ...
    trajectory.nodes.state_post(:, 1) / trajectory.model.distance_km, 'AbsTol', 1e-14);
axes_handle = nodes.Parent;
verifyEqual(testCase, axes_handle.View, [0, 90]);
verifyEqual(testCase, axes_handle.DataAspectRatio, [1, 1, 1]);
verifyEqual(testCase, axes_handle.XLabel.String, 'x [DU]');
verifyEqual(testCase, axes_handle.FontName, 'Times New Roman');
arrows = findobj(figure_handle, 'Type', 'quiver');
vectors = [arrows.UData(:), arrows.VData(:), arrows.WData(:)];
expected = trajectory.nodes.delta_v_km_s(1:2, :);
verifyEqual(testCase, vectors / norm(vectors(1, :)), ...
    expected / norm(expected(1, :)), 'AbsTol', 1e-14);
verifyEqual(testCase, trajectory, original);
end

function testEciUsesEpochRotationAndNoVelocityShiftForBurns(testCase)
trajectory = testCase.TestData.trajectory;
figure_handle = orb2ds.plot_trajectory(trajectory, struct('visible', 'off', 'frame', 'eci'));
cleanup = onCleanup(@() close(figure_handle));
expected_nodes = zeros(3);
expected_burns = zeros(3);
for index = 1:3
    angle = trajectory.model.moon_angle_ref_rad + trajectory.nodes.time_days(index) / ...
        trajectory.model.time_days;
    rotation = [cos(angle), -sin(angle), 0; sin(angle), cos(angle), 0; 0, 0, 1];
    position = trajectory.nodes.state_post(index, 1:3).' + ...
        [trajectory.model.mu * trajectory.model.distance_km; 0; 0];
    expected_nodes(index, :) = (rotation * position).';
    expected_burns(index, :) = (rotation * trajectory.nodes.delta_v_km_s(index, :).').';
end
nodes = findobj(figure_handle, 'DisplayName', 'Shooting nodes');
verifyEqual(testCase, [nodes.XData(:), nodes.YData(:), nodes.ZData(:)], ...
    expected_nodes, 'AbsTol', 1e-9);
verifyEqual(testCase, nodes.Parent.XLabel.String, 'x [km]');
arrows = findobj(figure_handle, 'Type', 'quiver');
vectors = [arrows.UData(:), arrows.VData(:), arrows.WData(:)];
verifyEqual(testCase, vectors / norm(vectors(1, :)), ...
    expected_burns(1:2, :) / norm(expected_burns(1, :)), 'AbsTol', 1e-14);
verifyNumElements(testCase, findobj(figure_handle, 'DisplayName', 'Moon path'), 1);
end

function testZeroBurnsAndHiddenNodes(testCase)
trajectory = testCase.TestData.trajectory;
trajectory.nodes.delta_v_km_s(:) = 0;
figure_handle = orb2ds.plot_trajectory(trajectory, ...
    struct('visible', 'off', 'show_nodes', false, 'view', [-37.5, 30]));
cleanup = onCleanup(@() close(figure_handle));
verifyEmpty(testCase, findobj(figure_handle, 'Type', 'quiver'));
verifyEmpty(testCase, findobj(figure_handle, 'DisplayName', 'Shooting nodes'));
verifyNumElements(testCase, findobj(figure_handle, 'DisplayName', 'Departure'), 1);
end

function testLibrarySummariesDoNotChangeOptimization(testCase)
options = testCase.TestData.options;
quiet_text = evalc('quiet = orb2ds.optimize_transfer(testCase.TestData.problem, testCase.TestData.solution, options);');
verifyEmpty(testCase, strtrim(quiet_text));
options.output.display = true;
text = evalc('verbose = orb2ds.optimize_transfer(testCase.TestData.problem, testCase.TestData.solution, options);');
verifyTrue(testCase, contains(text, 'Stage 1: feasibility'));
verifyTrue(testCase, contains(text, 'Stage 2: minimize delta-v'));
verifyTrue(testCase, contains(text, 'Shooting feasible:'));
verifyEqual(testCase, verbose.solution, quiet.solution);
verifyEqual(testCase, verbose.validation, quiet.validation);
end

function testSolverIterationsIndependentOfLibrarySummaries(testCase)
options = testCase.TestData.options;
options.solver.display = 'iter';
text = evalc('orb2ds.optimize_transfer(testCase.TestData.problem, testCase.TestData.solution, options);');
verifyTrue(testCase, contains(text, 'Iter') && contains(text, 'Func-count'));
verifyFalse(testCase, contains(text, 'Stage 1: feasibility'));
verifyFalse(testCase, contains(text, 'orb2ds result:'));
end
