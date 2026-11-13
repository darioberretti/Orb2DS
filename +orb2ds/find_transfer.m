function result = find_transfer(problem, supplied)
%FIND_TRANSFER Coordinate leg matching, assembly, mesh, optimization and validation.
%
% PROTOTYPE:
%   result = orb2ds.find_transfer(problem, options)
%
% DESCRIPTION:
%   Use the same directly callable scientific stages as the explicit API.
%   Single-start is the default. Optional deterministic multistart refines
%   distinct candidates from the existing ranking. Compare convergent delta-v
%   solves by cost, or select by validated cost when validation.require_pass
%   is enabled.
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
result = orb2ds.internal.empty_result(problem, options);
result.status = 'no_seed_found';
attempts = struct([]);
count = 0;
best = [];
for index = 1:numel(candidates)
    transfer = orb2ds.assemble_transfer(problem, candidates(index), options);
    if isempty(transfer)
        if options.output.display
            fprintf('\n[Orb2DS] Candidate assembly\n\n');
            fprintf('  Candidate                      : %d\n', index);
            fprintf('  Outcome                        : SKIPPED -- no assembled finite lunar passage\n');
        end
        continue
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
    current = orb2ds.optimize_transfer(problem, seed, options);
    count = count + 1;
    summary = struct('candidate_index', index, 'status', current.status, ...
        'is_feasible', current.validation.is_feasible, 'delta_v_m_s', current.validation.delta_v_m_s, ...
        'solver_converged', current.solver.converged);
    if orb2ds.internal.prefer_transfer(summary, best, options.validation.require_pass)
        result = current;
        best = summary;
    end
    if options.output.keep_attempt_solutions
        summary.solution = current.solution;
        summary.candidate = current.candidate;
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
if options.output.display && (options.n_starts > 1 || count == 0)
    fprintf('\n[Orb2DS] Transfer search result\n\n');
    fprintf('  Status                         : %s\n', result.status);
    fprintf('  Optimization attempts          : %d\n', count);
    if ~isempty(best)
        fprintf('  Selected delta-v [m/s]         : %.6f\n', best.delta_v_m_s);
        fprintf('  Selected candidate             : %d\n', best.candidate_index);
    end
end
end
