clc; close all; clear;
% Solve the example case and visualize a separately reconstructed trajectory.
% Requires base MATLAB and Optimization Toolbox. Edit a copied case function
% to change the scientific inputs. No results or plots are saved implicitly.

library_root = fileparts(fileparts(mfilename('fullpath')));
case_file = fullfile(library_root, 'examples', 'config_example.m');
addpath(library_root);

% Prepare inputs and execute the complete method.
[problem, options] = orb2ds.load_case(case_file);
result = orb2ds.find_transfer(problem, options);
disp(result.status);

% Inspect physical acceptance separately from the solver's stopping reason.
if ~isempty(result.solution)
    disp(result.solution.metrics);
    disp(result.validation.chained);
    trajectory = orb2ds.reconstruct_trajectory(result.solution);
    orb2ds.plot_trajectory(trajectory);
else
    disp(result.validation);
end
