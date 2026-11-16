function result = find_transfer(problem, supplied)
%FIND_TRANSFER Coordinate leg matching, assembly, mesh, optimization and validation.
%
% PROTOTYPE:
%   result = orb2ds.find_transfer(problem, options)
%
% DESCRIPTION:
%   Use the same directly callable scientific stages as the explicit API.
%   Single-start is the default. Powered matching assembles the shortlist and
%   refines the guesses with the lowest weighted burn. Ballistic matching refines
%   guesses in match order. Compare convergent delta-v solves by cost.
%   validation.require_pass enables validation and selects by validated cost.
%   A propagation or solver-timeline failure can end an individual start.
%   The search records the failure and continues with the remaining starts.
%   No database is generated and no transfer result is saved implicitly.
%
% INPUT:
%   problem  Complete in-memory case, including a compatible database.
%   options  Optional numerical settings. n_starts requests distinct starts;
%            patching.n_candidates must be at least that large.
% OUTPUT:
%   result   Shared compact result, search diagnostics and attempt summaries.
%            Full compact attempt solutions are optional; trajectories never
%            appear in any result field.

if nargin < 2
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
problem = orb2ds.internal.check_problem(problem);
orb2ds.internal.check_solver(options);
assert(options.patching.n_candidates >= options.n_starts, 'orb2ds:Options', ...
    'patching.n_candidates must be at least n_starts.');
[candidates, diagnostics] = orb2ds.find_legs(problem, options);
powered = strcmp(options.patching.method, 'powered');
order = 1:numel(candidates);
if powered
    [order, transfers] = orb2ds.internal.rank_powered_guesses(problem, candidates, options);
end
result = orb2ds.internal.empty_result(problem, options);
result.status = 'no_seed_found';
attempts = struct([]);
count = 0;
best = [];
for index = order
    if powered
        transfer = transfers{index};
    else
        transfer = orb2ds.assemble_transfer(problem, candidates(index), options);
    end
    if isempty(transfer)
        if options.output.display
            fprintf('\n[Orb2DS] Candidate assembly\n\n');
            fprintf('  Candidate                      : %d\n', index);
            fprintf('  Outcome                        : SKIPPED -- no assembled finite lunar passage\n');
        end
        continue
    end
    % Measure the initial junction before meshing assigns a single entry node.
    model = transfer.orbit.model;
    if isfield(transfer.provenance, 'powered_patch')
        gaps = transfer.provenance.powered_patch.soi_defects;
        entry_gap = hypot(gaps.position_km(1) / model.distance_km, ...
            gaps.velocity_km_s(1) / model.velocity_km_s);
    else
        epoch = transfer.events.moon_entry_days;
        orbit_entry = orb2ds.internal.evaluate_arc(transfer.arcs(1), epoch, model, options);
        flyby_entry = orb2ds.internal.evaluate_arc(transfer.arcs(2), epoch, model, options);
        scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
        entry_gap = norm((flyby_entry - orbit_entry) ./ scale);
    end
    seed = orb2ds.mesh_transfer(problem, transfer, options);
    if options.output.plot_initial_guess
        figure_handle = orb2ds.plot_initial_guess(transfer);
        figure_handle.Name = sprintf('Assembled initial guess: candidate %d', index);
        if strcmp(figure_handle.Visible, 'on')
            drawnow;
        end
    end
    if options.output.display
        fprintf('\n[Orb2DS] Transfer attempt %d/%d\n\n', count + 1, options.n_starts);
        fprintf('  Candidate                      : %d\n', index);
        fprintf('  Database row                   : %d\n', candidates(index).orbit_moon.row_id);
    end
    [summary, current] = optimize_start(problem, seed, options, index, entry_gap);
    count = count + 1;
    if isempty(current)
        if isempty(best)
            result.status = summary.status;
        end
    elseif orb2ds.internal.prefer_transfer(summary, best, options.validation.require_pass)
        result = current;
        best = summary;
    end
    if isempty(attempts)
        attempts = summary;
    else
        attempts(end + 1, 1) = summary;
    end
    if count >= options.n_starts
        break
    end
end
result.attempts = attempts;
result.search = diagnostics;
if options.output.display && (options.n_starts > 1 || isempty(best))
    fprintf('\n[Orb2DS] Transfer search result\n\n');
    fprintf('  Status                         : %s\n', result.status);
    fprintf('  Optimization attempts          : %d\n', count);
    if ~isempty(best)
        fprintf('  Selected delta-v [m/s]         : %.6f\n', best.delta_v_m_s);
        fprintf('  Selected candidate             : %d\n', best.candidate_index);
    end
end
end

function [summary, current] = optimize_start(problem, seed, options, index, entry_gap)
%OPTIMIZE_START Record an individual start, including a failed propagation.
summary = struct('candidate_index', index, 'status', 'integration_failed', ...
    'initial_delta_v_m_s', 1000 * sum(vecnorm(seed.nodes.delta_v_km_s, 2, 2)), ...
    'initial_soi_entry_state_gap_du_vu', entry_gap, ...
    'solver_max_constraint_violation', NaN, 'transfer_days', NaN, ...
    'is_feasible', false, 'delta_v_m_s', NaN, 'solver_converged', false, ...
    'integration_failure', '', 'solver_timeline_failure', '');
if options.output.keep_attempt_solutions
    summary.solution = [];
    summary.candidate = [];
end
try
    current = orb2ds.optimize_transfer(problem, seed, options);
catch exception
    switch exception.identifier
        case 'orb2ds:Integration'
            summary.integration_failure = exception.message;
            label = 'Integration failed';
        case 'orb2ds:SolverTimeline'
            summary.status = 'invalid_solver_timeline';
            summary.solver_timeline_failure = exception.message;
            label = 'Invalid solver timeline';
        otherwise
            rethrow(exception);
    end
    current = [];
    if options.output.display
        fprintf('  Outcome                        : %s\n', label);
        fprintf('  Detail                         : %s\n', exception.message);
    end
    return
end

record = current.solution;
if isempty(record)
    record = current.candidate;
end
solver = current.solver.optimization;
if isfield(solver, 'constrviolation')
    summary.solver_max_constraint_violation = solver.constrviolation;
elseif isfield(solver, 'inf_pr')
    summary.solver_max_constraint_violation = solver.inf_pr;
end
summary.status = current.status;
summary.transfer_days = record.timing.transfer_days;
summary.is_feasible = isfield(current.validation, 'is_feasible') && current.validation.is_feasible;
summary.delta_v_m_s = record.metrics.delta_v_m_s;
summary.solver_converged = current.solver.converged;
if options.output.keep_attempt_solutions
    summary.solution = current.solution;
    summary.candidate = current.candidate;
end
end
