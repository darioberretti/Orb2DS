function prefer = prefer_transfer(current, best, require_pass)
%PREFER_TRANSFER Rank stage or start summaries by the active selection policy.
%   Summaries carry is_feasible, solver_converged and delta_v_m_s. In exploration,
%   prioritize convergent delta-v solves, then validated fallback points and cost.
%   Strict selection uses validated cost and retains the last rejected fallback.

if isempty(best)
    prefer = true;
elseif ~require_pass && current.solver_converged ~= best.solver_converged
    prefer = current.solver_converged;
elseif (require_pass || ~current.solver_converged) && current.is_feasible ~= best.is_feasible
    prefer = current.is_feasible;
elseif require_pass && ~current.is_feasible
    prefer = true;
else
    prefer = current.delta_v_m_s < best.delta_v_m_s;
end
end
