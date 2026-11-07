clc; close all; clear;
% Build a reusable orbit-Moon catalogue, or load the same compatible archive.
% Edit config_database.m to choose the orbit, sampling and output files.
% Base MATLAB is sufficient. Re-running reuses a compatible database and
% exports its orbit descriptor for a separate transfer configuration.
% Generated files go to outputs/; choose another database filename after
% changing orbit, grid or integration settings.

library_root = fileparts(fileparts(mfilename('fullpath')));
configuration_file = fullfile(library_root, 'examples', 'config_database.m');
addpath(library_root);

% Read generation settings without loading a transfer or an existing database.
cfg = read_configuration(configuration_file);
assert(~strcmpi(cfg.output.database, cfg.output.orbit), ...
    'Choose distinct database and orbit output files.');

% Prepare output folders, then explicitly create or reuse the archive.
for filename = {cfg.output.database, cfg.output.orbit}
    folder = fileparts(filename{1});
    if ~isfolder(folder)
        mkdir(folder);
    end
end
existed = isfile(cfg.output.database);
generation_timer = tic;
database = orb2ds.build_orbit_moon_database(cfg.orbit, cfg.output.database, cfg.options);
elapsed_seconds = toc(generation_timer);
if existed
    fprintf('Reused compatible database: %s\n', cfg.output.database);
else
    fprintf('Created database: %s\n', cfg.output.database);
end
fprintf('Encounters: %d; elapsed %.3f s\n', ...
    numel(database.encounters.row_id), elapsed_seconds);
disp(database.generation);

% Export a compact orbit input; transfer settings can refer to this MAT file.
orbit = database.orbit;
save(cfg.output.orbit, 'orbit');
fprintf('Exported orbit: %s\n', cfg.output.orbit);
% Set cfg.files.database and cfg.files.orbit in config_transfer.m to these files,
% removing its inline cfg.orbit when selecting the orbit-file alternative.

function cfg = read_configuration(configuration_file)
%READ_CONFIGURATION Invoke the selected function without changing the caller's folder.
[configuration_directory, configuration_name] = fileparts(configuration_file);
original_directory = pwd;
restore_directory = onCleanup(@() cd(original_directory));
cd(configuration_directory);
cfg = feval(configuration_name);
end
