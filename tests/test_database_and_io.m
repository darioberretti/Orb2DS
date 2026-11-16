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
filename = fullfile(testCase.TestData.directory, 'generated', 'encounters.mat');
options.database = struct('phases', [0, 0.25, 0.5, 0.75], ...
    'impulses_m_s', [0, 20], 'azimuths_rad', (0:4) * pi / 2, ...
    'elevations_rad', 0, 'horizon_days', 20);
options.output.display = false;
database = orb2ds.build_orbit_moon_database(testCase.TestData.orbit, filename, options);
verifyGreaterThan(testCase, numel(database.encounters.row_id), 0);
verifyEqual(testCase, database.generation.grid.azimuths_rad, (0:3) * pi / 2);
entries = database.encounters;
keys = [entries.departure_phase, entries.delta_v_km_s, entries.duration_days];
verifyEqual(testCase, keys, unique(keys, 'rows', 'stable'));
verifyTrue(testCase, isfile(filename));
file_info = dir(filename);
options.database.azimuths_rad(end) = [];
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
    verifyEqual(testCase, problem.constraints.max_wait_time_days, 0);
    verifyEqual(testCase, options.n_starts, 1);
    verifyEqual(testCase, pwd, original_directory);
end
end

function testCompletePortableConfiguration(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
template = fullfile(root, 'examples', 'config_transfer.m');
original_directory = pwd;
restore = onCleanup(@() cd(original_directory));
cd(fileparts(template));
cfg = config_transfer();
cd(original_directory);
defaults = orb2ds.defaults.numerical_options();
verify_option_fields(testCase, cfg.options, rmfield(defaults, 'database'));

% An unchanged copy must load the same scientific inputs outside examples.
destination = fullfile(testCase.TestData.directory, 'config_transfer.m');
copyfile(template, destination);
[original, original_options, original_output] = orb2ds.load_case(template);
[relocated, relocated_options, relocated_output] = orb2ds.load_case(destination);
verifyEqual(testCase, relocated, original);
verifyEqual(testCase, relocated_options, original_options);
verifyEqual(testCase, original_output.directory, fullfile(fileparts(template), 'Orb2DS_output'));
verifyEqual(testCase, relocated_output.directory, fullfile(fileparts(destination), 'Orb2DS_output'));
verifyFalse(testCase, relocated_output.overwrite_without_prompt);
verifyFalse(testCase, isfolder(relocated_output.directory));
verifyEqual(testCase, pwd, original_directory);
verifyFalse(testCase, isfield(relocated.constraints, 'initial_time_days'));
verifyFalse(testCase, isfield(relocated.constraints, 'initial_phase'));
verifyFalse(testCase, isfield(relocated.constraints, 'final_time_days'));
verifyEqual(testCase, relocated.constraints.max_wait_time_days, 0);
verifyEqual(testCase, numel(relocated.database.encounters.row_id), 1986);
end

function testCopiedWorkspaceBuildReuseAndLoad(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
workspace = fullfile(testCase.TestData.directory, 'workspace');
copyfile(fullfile(root, 'examples', 'workspace'), workspace);

% Keep the real copied workflow fast with a small generation grid.
configuration = fullfile(workspace, 'config_database.m');
text = fileread(configuration);
text = replace(text, '(0:11) / 12', '[0, 0.25, 0.5, 0.75]');
text = replace(text, '[0, 10, 20, 30, 50]', '[0, 20]');
text = replace(text, '(0:11) * 2*pi/12', '(0:3) * pi/2');
text = replace(text, 'horizon_days = 50', 'horizon_days = 20');
text = replace(text, 'display = true', 'display = false');
file = fopen(configuration, 'w');
fprintf(file, '%s', text);
fclose(file);

% Execute as a user would from an unrelated current folder, then reuse it.
original_directory = pwd;
run_build_script(fullfile(workspace, 'build_database.m'));
database_file = fullfile(workspace, 'databases', 'orbit_moon.mat');
created = dir(database_file);
orbit_file = fullfile(workspace, 'databases', 'orbit.mat');
created_orbit = dir(orbit_file);
run_build_script(fullfile(workspace, 'build_database.m'));
verifyEqual(testCase, dir(database_file).datenum, created.datenum);
verifyEqual(testCase, dir(orbit_file).datenum, created_orbit.datenum);
verifyEqual(testCase, pwd, original_directory);

[problem, options] = orb2ds.load_case(fullfile(workspace, 'config_transfer.m'));
verifyEqual(testCase, problem.orbit, problem.database.orbit);
verifyGreaterThan(testCase, numel(problem.database.encounters.row_id), 0);
verifyEqual(testCase, options.solver.name, 'fmincon');
verifyEqual(testCase, problem.constraints.max_wait_time_days, 0);
end

function run_build_script(filename)
%RUN_BUILD_SCRIPT Isolate the example's clear statement from the test caller.
run(filename);
end

function verify_option_fields(testCase, configured, defaults)
%VERIFY_OPTION_FIELDS Ensure the reference explicitly exposes every numerical leaf.
if isempty(fieldnames(defaults))
    verifyTrue(testCase, isstruct(configured) && isscalar(configured));
    return
end
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
