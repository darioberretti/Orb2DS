clc; close all; clear;
% Find a transfer, save the compact result and inspect the returned trajectory.
% Add the Orb2DS root to MATLAB's path and run build_database.m first.
% Edit config_transfer.m for inputs/settings. fmincon requires Optimization
% Toolbox; IPOPT requires CasADi on the path. Output paths and replacement
% permission are in config_transfer.m. Existing files are checked before
% matching/optimization. Sampled trajectories are never saved in the result.

workspace_root = fileparts(mfilename('fullpath'));
configuration_file = fullfile(workspace_root, 'config_transfer.m');

% Load inputs and authorize saving before starting numerical work.
[problem, options, output] = orb2ds.load_case(configuration_file);
destination = orb2ds.prepare_output(output.directory, output.filename, ...
    struct('overwrite_without_prompt', output.overwrite_without_prompt, ...
    'display', options.output.display));
if isempty(destination)
    return
end
result = orb2ds.find_transfer(problem, options);
disp(result.status);

% Save only the compact result, before creating separate plot samples.
orb2ds.save_output(destination, output.filename, struct('result', result));

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
