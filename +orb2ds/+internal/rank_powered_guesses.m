function [order, transfers] = rank_powered_guesses(problem, candidates, options)
%RANK_POWERED_GUESSES Rank the powered shortlist by the assembled weighted burn.
%
%   Return the usable match indices in ascending ranking cost [m/s],
%   retaining the provisional order for ties. Transfers are indexed by the
%   original match so selected guesses can be meshed without reassembly.

transfers = cell(size(candidates));
delta_v_m_s = inf(1, numel(candidates));
ranking_cost_m_s = inf(1, numel(candidates));
assembly_options = options;
assembly_options.output.display = false;
for index = 1:numel(candidates)
    transfer = orb2ds.assemble_transfer(problem, candidates(index), assembly_options);
    if ~isempty(transfer)
        transfers{index} = transfer;
        patch = transfer.provenance.powered_patch;
        delta_v_m_s(index) = 1000 * patch.total_delta_v_km_s;
        ranking_cost_m_s(index) = 1000 * patch.ranking_cost_km_s;
    end
end
[costs, order] = sort(ranking_cost_m_s);
order = order(isfinite(costs));

if options.output.display
    fprintf('\n[Orb2DS] Powered guess ranking\n\n');
    fprintf('  Usable assemblies              : %d / %d\n', numel(order), numel(candidates));
    if ~isempty(order)
        fprintf('\n  %8s %8s %23s %23s\n', ...
            'Rank', 'Match', 'Assembled delta-v [m/s]', 'Ranking cost [m/s]');
        fprintf('  %8d %8d %23.6f %23.6f\n', ...
            [1:numel(order); order; delta_v_m_s(order); ranking_cost_m_s(order)]);
    end
end
end
