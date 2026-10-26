clc; close all; clear;
% Inspect every scientific stage before running the optimizer. Execute the
% sections separately in the MATLAB editor, or run the whole script.
% Edit physical inputs, search settings and verbosity in the case function;
% edit candidate selection and visualization below. Requires Optimization
% Toolbox. No results or figures are saved automatically.

library_root = fileparts(fileparts(mfilename('fullpath')));
case_file = fullfile(library_root, 'examples', 'config_example.m');
candidate_index = 1;  % Rank in the returned matches, not a database row.
show_initial_guess = true;
plot_settings = struct('frame', 'rotating', 'view', [0, 90], ...
    'show_nodes', true, 'show_impulses', true, 'impulse_scale', 0.38);
addpath(library_root);

%% 1. Prepare physical inputs and resolve numerical defaults.
[problem, options] = orb2ds.load_case(case_file);

%% 2. Inspect the ranked leg matches before choosing one.
[candidates, search] = orb2ds.find_legs(problem, options);
disp(search);
assert(candidate_index <= numel(candidates), 'The search did not return this candidate.');
matches = candidates(:);
candidate_table = table((1:numel(matches)).', ...
    arrayfun(@(item) item.orbit_moon.row_id, matches), ...
    arrayfun(@(item) item.orbit_moon.departure_phase, matches), ...
    1000 * arrayfun(@(item) norm(item.orbit_moon.delta_v_km_s), matches), ...
    1000 * arrayfun(@(item) item.ranking.earth_delta_v_km_s, matches), ...
    1000 * arrayfun(@(item) item.ranking.speed_mismatch_km_s, matches), ...
    'VariableNames', {'Candidate', 'DatabaseRow', 'DeparturePhase', ...
    'OrbitBurn_m_s', 'EarthBurn_m_s', 'MoonSpeedMismatch_m_s'});
disp(candidate_table);

%% 3. Assemble the chosen match with a finite lunar passage.
fprintf('Selected candidate %d, database row %d\n', ...
    candidate_index, candidates(candidate_index).orbit_moon.row_id);
transfer = orb2ds.assemble_transfer(problem, candidates(candidate_index), options);
assert(~isempty(transfer), 'This candidate has no assembled finite lunar passage.');
disp(transfer.events);

%% 4. Choose shooting nodes and inspect the initial guess.
seed = orb2ds.mesh_transfer(problem, transfer, options);
fprintf('Initial guess: %d nodes, delta-v %.6f m/s, flight %.6f days\n', ...
    numel(seed.nodes.time_days), 1000 * sum(vecnorm(seed.nodes.delta_v_km_s, 2, 2)), ...
    seed.timing.transfer_days);
if show_initial_guess
    guess_trajectory = orb2ds.reconstruct_trajectory(seed);
    guess_figure = orb2ds.plot_trajectory(guess_trajectory, plot_settings);
    guess_figure.Name = 'Initial multiple-shooting guess';
end

%% 5. Optimize the supplied mesh; the database is no longer needed.
problem = rmfield(problem, 'database');
result = orb2ds.optimize_transfer(problem, seed, options);
disp(result.status);

%% 6. Reconstruct a validated solution independently of the compact result.
if ~isempty(result.solution)
    disp(result.solution.timing);
    disp(result.validation.chained);
    trajectory = orb2ds.reconstruct_trajectory(result.solution);
    solution_figure = orb2ds.plot_trajectory(trajectory, plot_settings);
    solution_figure.Name = 'Validated optimized transfer';
end
