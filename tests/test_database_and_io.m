function tests = test_database_and_io
%TEST_DATABASE_AND_IO Check reproducible encounter generation and case loading.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup_path = onCleanup(@() path(old_path));
directory = tempname;
mkdir(directory);
testCase.TestData.directory = directory;
testCase.TestData.cleanup_files = onCleanup(@() rmdir(directory, 's'));
model = orb2ds.earth_moon_model();
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
testCase.TestData.orbit = struct('schema_version', 1, ...
    'state_ref', [-1.1377073434659586; 0; 0; 0; 1.9863955242330344; 0] .* scale, ...
    'period_days', 3.395596937863704 * model.time_days, 'model', model);
end

function testGenerateReuseAndMismatch(testCase)
filename = fullfile(testCase.TestData.directory, 'encounters.mat');
options.database = struct('phases', [0, 0.25, 0.5, 0.75], ...
    'impulses_m_s', [0, 20], 'azimuths_rad', (0:3) * pi / 2, ...
    'elevations_rad', 0, 'horizon_days', 20);
options.output.display = false;
database = orb2ds.build_orbit_moon_database(testCase.TestData.orbit, filename, options);
verifyGreaterThan(testCase, numel(database.encounters.row_id), 0);
verifyTrue(testCase, isfile(filename));
file_info = dir(filename);
reused = orb2ds.build_orbit_moon_database(testCase.TestData.orbit, filename, options);
verifyEqual(testCase, database, reused);
verifyEqual(testCase, dir(filename).datenum, file_info.datenum);
options.database.horizon_days = 21;
verifyError(testCase, @() orb2ds.build_orbit_moon_database( ...
    testCase.TestData.orbit, filename, options), 'orb2ds:DatabaseSettings');
different = testCase.TestData.orbit;
different.period_days = different.period_days + 0.1;
verifyError(testCase, @() orb2ds.internal.same_orbit(database.orbit, different), ...
    'orb2ds:OrbitMismatch');
end

function testCaseRelativePathsAndLookup(testCase)
original_directory = pwd;
orbit = testCase.TestData.orbit;
directories = {fullfile(testCase.TestData.directory, 'first'), ...
    fullfile(testCase.TestData.directory, 'second')};
for index = 1:2
    mkdir(directories{index});
    save(fullfile(directories{index}, 'orbit.mat'), 'orbit');
    filename = fullfile(directories{index}, 'sample_case.m');
    file = fopen(filename, 'w');
    fprintf(file, ['function cfg = sample_case()\n' ...
        'cfg.files.orbit = ''orbit.mat'';\n' ...
        'cfg.target = struct(''vinf_km_s'', [%d; 1; 0], ''frame'', ''eci'');\n' ...
        'end\n'], index);
    fclose(file);
    [problem, options] = orb2ds.load_case(filename);
    verifyEqual(testCase, problem.target.vinf_km_s(1), index);
    verifyFalse(testCase, isfield(problem.constraints, 'initial_phase'));
    verifyFalse(testCase, isfield(problem.constraints, 'initial_time_days'));
    verifyEqual(testCase, options.n_starts, 1);
    verifyEqual(testCase, pwd, original_directory);
end
end

function testCompletePortableConfiguration(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
template = fullfile(root, 'examples', 'config_example.m');
original_directory = pwd;
restore = onCleanup(@() cd(original_directory));
cd(fileparts(template));
cfg = config_example();
cd(original_directory);
verify_option_fields(testCase, cfg.options, orb2ds.defaults.numerical_options());

% An unchanged copy must load the same scientific inputs outside examples.
destination = fullfile(testCase.TestData.directory, 'config_example.m');
copyfile(template, destination);
[original, original_options] = orb2ds.load_case(template);
[relocated, relocated_options] = orb2ds.load_case(destination);
verifyEqual(testCase, relocated, original);
verifyEqual(testCase, relocated_options, original_options);
verifyEqual(testCase, pwd, original_directory);
verifyFalse(testCase, isfield(relocated.constraints, 'initial_time_days'));
verifyFalse(testCase, isfield(relocated.constraints, 'initial_phase'));
verifyFalse(testCase, isfield(relocated.constraints, 'final_time_days'));
verifyEqual(testCase, numel(relocated.database.encounters.row_id), 1986);
end

function verify_option_fields(testCase, configured, defaults)
%VERIFY_OPTION_FIELDS Ensure the reference explicitly exposes every numerical leaf.
verifyEqual(testCase, sort(fieldnames(configured)), sort(fieldnames(defaults)));
names = fieldnames(defaults);
for index = 1:numel(names)
    name = names{index};
    if isstruct(defaults.(name))
        verify_option_fields(testCase, configured.(name), defaults.(name));
    end
end
end

function testReconstructionPreservesImpulseJumps(testCase)
orbit = testCase.TestData.orbit;
model = orbit.model;
options = orb2ds.defaults.numerical_options();
scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
initial = orbit.state_ref ./ scale.';
second = orb2ds.internal.propagate(initial, [0, 0.03], model, options);
impulse = [0.001, -0.002, 0.0005];
second(4:6) = second(4:6) + impulse.'/model.velocity_km_s;
last = orb2ds.internal.propagate(second, [0.03, 0.06], model, options);
record = struct('schema_version', 1, 'orbit', orbit, ...
    'nodes', struct('time_days', [0; 0.03; 0.06] * model.time_days, ...
    'state_post', [initial.'; second.'; last.'] .* scale, ...
    'delta_v_km_s', [zeros(1, 3); impulse; zeros(1, 3)]), ...
    'events', struct(), 'timing', struct('departure_phase', 0), ...
    'integration', options.integration, 'provenance', struct());
copy = record;
trajectory = orb2ds.reconstruct_trajectory(record, struct('samples_per_segment', 5));
verifyEqual(testCase, record, copy);
verifyLessThan(testCase, max(vecnorm(trajectory.defects(:, 1:3), 2, 2)), 1e-5);
verifyLessThan(testCase, max(vecnorm(trajectory.defects(:, 4:6), 2, 2)), 1e-9);
jump = trajectory.nodes.state_post(2, 4:6) - ...
    trajectory.segments{1}.state(end, 4:6);
verifyEqual(testCase, jump, impulse, 'AbsTol', 1e-9);
end
