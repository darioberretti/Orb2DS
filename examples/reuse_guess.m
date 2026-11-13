clc; close all; clear;
% Reuse an assembled discretized guess for a modified target.
% A previous result.solution can be supplied in place of seed as well.

library_root = fileparts(fileparts(mfilename('fullpath')));
case_file = fullfile(library_root, 'examples', 'config_transfer.m');
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

% Locate the in-memory data without repeating the physical summary.
if options.output.display
    fprintf('\n[Orb2DS] Result data\n\n');
    fprintf('  Storage                        : MATLAB workspace only\n');
    fprintf('  Variable                       : result\n');
    if ~isempty(result.solution)
        fprintf('  Transfer record                : result.solution\n');
    elseif ~isempty(result.candidate)
        fprintf('  Transfer record                : result.candidate\n');
    else
        fprintf('  Transfer record                : NONE\n');
    end
    fprintf('  Node table                     : nodes = orb2ds.node_table(result);\n');
    fprintf('  Open table                     : openvar(''nodes'');\n');
    fprintf('  Full report                    : orb2ds.print_result(result);\n');
end
