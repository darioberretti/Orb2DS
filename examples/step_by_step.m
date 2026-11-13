clc; close all; clear;
% Inspect every scientific stage before running the optimizer. Execute the
% sections separately in the MATLAB editor, or run the whole script.
% Edit physical inputs, search settings and verbosity in the case function;
% edit candidate selection and visualization below. fmincon requires
% Optimization Toolbox; for IPOPT, first add your CasADi installation to the
% path. No results or figures are saved automatically.

library_root = fileparts(fileparts(mfilename('fullpath')));
case_file = fullfile(library_root, 'examples', 'config_transfer.m');
candidate_index = 1;  % Rank in the returned matches, not a database row.
plot_settings = struct('frame', 'rotating', 'view', [0, 90], ...
    'show_nodes', true, 'show_impulses', true, 'impulse_scale', 0.38, 'show_defects', true);
addpath(library_root);

%% 1. Prepare physical inputs and resolve numerical defaults.
[problem, options] = orb2ds.load_case(case_file);

%% 2. Inspect the ranked leg matches before choosing one.
[candidates, search] = orb2ds.find_legs(problem, options);
assert(candidate_index <= numel(candidates), 'The search did not return this candidate.');
matches = candidates(:);
candidate_table = table((1:numel(matches)).', ...
    arrayfun(@(item) item.orbit_moon.row_id, matches), ...
    arrayfun(@(item) item.orbit_moon.departure_phase, matches), ...
    1000 * arrayfun(@(item) norm(item.orbit_moon.delta_v_km_s), matches), ...
    1000 * arrayfun(@(item) item.ranking.earth_delta_v_km_s, matches), ...
    1000 * arrayfun(@(item) item.ranking.speed_mismatch_km_s, matches), ...
    arrayfun(@(item) item.timing.wait_days, matches), ...
    arrayfun(@(item) item.timing.transfer_days, matches), ...
    arrayfun(@(item) item.timing.moon_phase_mismatch_rad, matches), ...
    'VariableNames', {'Candidate', 'DatabaseRow', 'DeparturePhase', ...
    'OrbitBurn_m_s', 'EarthBurn_m_s', 'MoonSpeedMismatch_m_s', ...
    'Wait_days', 'EstimatedFlight_days', 'MoonEpochMismatch_rad'});
fprintf('\n[Orb2DS] Ranked candidates\n\n');
disp(candidate_table);

%% 3. Assemble the chosen match with a finite lunar passage.
fprintf('\n[Orb2DS] Candidate selection\n\n');
fprintf('  Candidate                      : %d\n', candidate_index);
fprintf('  Database row                   : %d\n', candidates(candidate_index).orbit_moon.row_id);
transfer = orb2ds.assemble_transfer(problem, candidates(candidate_index), options);
assert(~isempty(transfer), 'This candidate has no assembled finite lunar passage.');
if options.output.plot_initial_guess
    orb2ds.plot_initial_guess(transfer, [], plot_settings);
end

%% 4. Discretize the assembled transfer for multiple shooting.
[seed, mesh_summary] = orb2ds.mesh_transfer(problem, transfer, options);

%% 5. Inspect the exact NLP initialization without running a solver.
nlp_guess = orb2ds.transcribe_guess(problem, seed, options);
if options.output.plot_nlp_guess
    nlp_trajectory = orb2ds.reconstruct_trajectory(nlp_guess);
    nlp_figure = orb2ds.plot_trajectory(nlp_trajectory, plot_settings);
    nlp_figure.Name = 'NLP-transcribed initial guess';
    if strcmp(nlp_figure.Visible, 'on')
        drawnow;
    end
end

%% 6. Optimize the supplied mesh; the database is no longer needed.
% The explicit preview above replaces optimize_transfer's automatic preview.
solve_options = options;
solve_options.output.plot_nlp_guess = false;
problem = rmfield(problem, 'database');
result = orb2ds.optimize_transfer(problem, seed, solve_options);

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


%% 7. Reconstruct the final solution or unvalidated optimization candidate.
final_record = result.solution;
plot_label = 'Validated optimized transfer';
if isempty(final_record)
    final_record = result.candidate;
    plot_label = 'Unvalidated optimization candidate';
end
if ~isempty(final_record)
    trajectory = orb2ds.reconstruct_trajectory(final_record);
    solution_figure = orb2ds.plot_trajectory(trajectory, plot_settings);
    solution_figure.Name = plot_label;
    title(solution_figure.CurrentAxes, {plot_label, solution_figure.CurrentAxes.Title.String}, ...
        'Interpreter', 'latex');
end
