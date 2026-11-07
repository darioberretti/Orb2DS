clc; close all; clear;
% Solve the example with assembled and NLP-transcribed initial-guess figures,
% then reconstruct the final solution or unvalidated candidate. Select the
% mesh, refinement, solver and initial-plot flags in a copied config_transfer.
% Requires Optimization Toolbox for fmincon or CasADi/IPOPT on the path for
% IPOPT. No transfer results or figures are saved automatically.

library_root = fileparts(fileparts(mfilename('fullpath')));
% For IPOPT, first add your CasADi installation root, for example:
% addpath('C:\path\to\casadi');
case_file = fullfile(library_root, 'examples', 'config_transfer.m');
addpath(library_root);

% Prepare inputs and execute the complete method.
[problem, options] = orb2ds.load_case(case_file);
result = orb2ds.find_transfer(problem, options);
disp(result.status);

% Always inspect a returned candidate; its label reports physical acceptance.
final_record = result.solution;
plot_label = 'Validated optimized transfer';
if isempty(final_record)
    final_record = result.candidate;
    plot_label = 'Unvalidated optimization candidate';
end
if ~isempty(final_record)
    disp(final_record.metrics);
    disp(result.validation.checks);
    disp(result.validation.chained);
    trajectory = orb2ds.reconstruct_trajectory(final_record);
    final_figure = orb2ds.plot_trajectory(trajectory, struct('show_defects', true));
    final_figure.Name = plot_label;
    title(final_figure.CurrentAxes, {plot_label, final_figure.CurrentAxes.Title.String}, ...
        'Interpreter', 'latex');
end
