clc; close all; clear;
% Build a reusable orbit-Moon catalogue, or load the same compatible archive.
% Edit the orbit and options.database grid in config_example.m. This example
% reads configuration directly, without loading cfg.files.database or using
% the transfer target. Base MATLAB is sufficient; no optimization is run.
% The generated MAT file is saved explicitly under ignored outputs/.
% Re-running reuses it only with the same orbit, grid and integration options.
% After changing those settings, choose a different output filename.

library_root = fileparts(fileparts(mfilename('fullpath')));
configuration_file = fullfile(library_root, 'examples', 'config_example.m');
output_file = fullfile(library_root, 'outputs', 'orbit_moon_generated.mat');
addpath(library_root);

% Read the declared orbit only; a database file need not exist yet.
[orbit, options] = load_generation_inputs(configuration_file);

% Prepare the destination and explicitly create or reuse the archive.
output_directory = fileparts(output_file);
if ~isfolder(output_directory)
    mkdir(output_directory);
end
existed = isfile(output_file);
generation_timer = tic;
database = orb2ds.build_orbit_moon_database(orbit, output_file, options);
elapsed_seconds = toc(generation_timer);
if existed
    fprintf('Reused compatible database: %s\n', output_file);
else
    fprintf('Created database: %s\n', output_file);
end
fprintf('Encounters: %d; elapsed %.3f s\n', ...
    numel(database.encounters.row_id), elapsed_seconds);
disp(database.generation);

% Use this archive in a transfer by setting cfg.files.database = output_file
% in your configuration, or assign problem.database = database in your script.

function [orbit, options] = load_generation_inputs(configuration_file)
%LOAD_GENERATION_INPUTS Read orbit/options without loading a transfer database.
%   Relative orbit files resolve against the config directory. Function scope
%   restores the caller's directory on success and on configuration errors.
[configuration_directory, configuration_name] = fileparts(configuration_file);
original_directory = pwd;
restore_directory = onCleanup(@() cd(original_directory));
cd(configuration_directory);
cfg = feval(configuration_name);
has_inline = isfield(cfg, 'orbit');
has_file = isfield(cfg, 'files') && isfield(cfg.files, 'orbit');
assert(xor(has_inline, has_file), 'Specify exactly one of cfg.orbit and cfg.files.orbit.');
if has_inline
    orbit = cfg.orbit;
else
    orbit_data = load(cfg.files.orbit, 'orbit');
    orbit = orbit_data.orbit;
end
options = struct();
if isfield(cfg, 'options')
    options = cfg.options;
end
end
