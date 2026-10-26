clc; close all; clear;
% Reuse an assembled discretized guess for a modified target.
% A previous result.solution can be supplied in place of seed as well.

library_root = fileparts(fileparts(mfilename('fullpath')));
case_file = fullfile(library_root, 'examples', 'config_example.m');
target_change_km_s = [0.02; 0; 0];
addpath(library_root);

% Build an initialization once, then change the requested scientific problem.
[problem, options] = orb2ds.load_case(case_file);
seed = orb2ds.build_initial_guess(problem, options);
assert(~isempty(seed), 'The selected finite search found no assembled guess.');
problem.target.vinf_km_s = problem.target.vinf_km_s + target_change_km_s;
problem = rmfield(problem, 'database');

% Optimization does not repeat matching or silently change the mesh.
result = orb2ds.optimize_transfer(problem, seed, options);
disp(result.status);
if ~isempty(result.solution)
    disp(result.solution.metrics);
end
