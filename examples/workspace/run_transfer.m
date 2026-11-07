clc; close all; clear;
% Find a transfer, save the compact result and inspect the returned trajectory.
% Add the Orb2DS root to MATLAB's path and run build_database.m first.
% Edit config_transfer.m for inputs/settings. fmincon requires Optimization
% Toolbox; IPOPT requires CasADi on the path. outputs/transfer_result.mat is
% replaced on each completed call; sampled trajectories are never saved there.

workspace_root = fileparts(mfilename('fullpath'));
configuration_file = fullfile(workspace_root, 'config_transfer.m');

% Load the explicit orbit/database and execute the public transfer pipeline.
[problem, options] = orb2ds.load_case(configuration_file);
result = orb2ds.find_transfer(problem, options);
disp(result.status);

% Save only the compact result, before creating separate plot samples.
output_directory = fullfile(workspace_root, 'outputs');
if ~isfolder(output_directory)
    mkdir(output_directory);
end
output_file = fullfile(output_directory, 'transfer_result.mat');
save(output_file, 'result');
fprintf('Saved result: %s\n', output_file);

% Always inspect a returned point, including one rejected by physical checks.
record = result.solution;
plot_label = 'Validated optimized transfer';
if isempty(record)
    record = result.candidate;
    plot_label = 'Unvalidated optimization candidate';
end
if ~isempty(record)
    disp(record.metrics);
    disp(result.validation.checks);
    disp(result.validation.chained);
    trajectory = orb2ds.reconstruct_trajectory(record);
    transfer_figure = orb2ds.plot_trajectory(trajectory, struct('show_defects', true));
    transfer_figure.Name = plot_label;
    title(transfer_figure.CurrentAxes, {plot_label, transfer_figure.CurrentAxes.Title.String}, ...
        'Interpreter', 'latex');
end
