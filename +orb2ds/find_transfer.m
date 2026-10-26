function result = find_transfer(problem, supplied)
%FIND_TRANSFER Coordinate leg matching, assembly, mesh, optimization and validation.
%
% PROTOTYPE:
%   result = orb2ds.find_transfer(problem, options)
%
% DESCRIPTION:
%   Use the same directly callable scientific stages as the explicit API.
%   Single-start is the default. Optional deterministic multistart refines
%   distinct candidates from the existing ranking and selects the lowest
%   validated delta-v. An exhausted search is not a proof of infeasibility.
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
assert(options.patching.n_candidates >= options.n_starts, 'orb2ds:Options', ...
    'patching.n_candidates must be at least n_starts.');
[candidates, diagnostics] = orb2ds.find_legs(problem, options);
result = orb2ds.internal.empty_result(problem, options);
result.status = 'no_seed_found';
attempts = struct([]);
count = 0;
best_cost = inf;
for index = 1:numel(candidates)
    transfer = orb2ds.assemble_transfer(problem, candidates(index), options);
    if isempty(transfer)
        if options.output.display
            fprintf('orb2ds candidate %d: no assembled finite lunar passage; skipping\n', index);
        end
        continue
    end
    seed = orb2ds.mesh_transfer(problem, transfer, options);
    if options.output.display
        fprintf('\norb2ds start %d/%d: candidate %d, database row %d\n', ...
            count + 1, options.n_starts, index, candidates(index).orbit_moon.row_id);
    end
    current = orb2ds.optimize_transfer(problem, seed, options);
    count = count + 1;
    summary = struct('candidate_index', index, 'status', current.status, ...
        'is_feasible', ~isempty(current.solution), 'delta_v_m_s', NaN, ...
        'solver_converged', current.solver.converged);
    if ~isempty(current.solution)
        summary.delta_v_m_s = current.solution.metrics.delta_v_m_s;
        if summary.delta_v_m_s < best_cost
            result = current;
            best_cost = summary.delta_v_m_s;
        end
    elseif isempty(result.solution)
        result = current;
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
end
