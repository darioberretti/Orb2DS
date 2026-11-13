clc; close all; clear;
% Build a reusable orbit-Moon catalogue, or load the same compatible archive.
% Edit config_database.m to choose the orbit, sampling and output files.
% Base MATLAB is sufficient. Re-running reuses a compatible database and
% exports its orbit descriptor for a separate transfer configuration.
% Add the Orb2DS root to MATLAB's path first. Files go to databases/.
% Choose another database filename after changing orbit, grid or integration.

workspace_root = fileparts(mfilename('fullpath'));
configuration_file = fullfile(workspace_root, 'config_database.m');

% Read generation settings without loading a transfer or an existing database.
cfg = read_configuration(configuration_file);
assert(~strcmpi(cfg.output.database, cfg.output.orbit), ...
    'Choose distinct database and orbit output files.');

% Protect the reusable orbit input before starting database generation.
[orbit_folder, orbit_name, orbit_extension] = fileparts(cfg.output.orbit);
orbit_destination = [];
if isfile(cfg.output.orbit)
    stored = load(cfg.output.orbit, 'orbit');
    assert(isfield(stored, 'orbit') && isequaln(stored.orbit, cfg.orbit), ...
        'Existing orbit input differs; choose another orbit output filename.');
    if cfg.options.output.display
        fprintf('\n[Orb2DS] Orbit input reuse\n\n');
        fprintf('  File                           : %s\n', cfg.output.orbit);
    end
else
    orbit_destination = orb2ds.prepare_output(orbit_folder, [orbit_name, orbit_extension], ...
        struct('display', cfg.options.output.display));
    if isempty(orbit_destination)
        return
    end
end

% A compatible database is reused; incompatible archives are never overwritten.
database = orb2ds.build_orbit_moon_database(cfg.orbit, cfg.output.database, cfg.options);

% Export a new orbit input only; an identical existing descriptor stays untouched.
if ~isempty(orbit_destination)
    orb2ds.save_output(orbit_destination, [orbit_name, orbit_extension], ...
        struct('orbit', database.orbit));
end

function cfg = read_configuration(configuration_file)
%READ_CONFIGURATION Invoke the selected function without changing the caller's folder.
[configuration_directory, configuration_name] = fileparts(configuration_file);
original_directory = pwd;
restore_directory = onCleanup(@() cd(original_directory));
cd(configuration_directory);
cfg = feval(configuration_name);
end
