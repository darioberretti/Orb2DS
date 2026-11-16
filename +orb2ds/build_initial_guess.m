function [seed, diagnostics] = build_initial_guess(problem, supplied)
%BUILD_INITIAL_GUESS Compose matching, physical assembly and explicit meshing.
%
% PROTOTYPE:
%   [seed, diagnostics] = orb2ds.build_initial_guess(problem, options)
% INPUT:
%   problem/options  Same contracts as find_transfer.
% OUTPUT:
%   seed         Lowest weighted-cost powered guess or first usable
%                ballistic match, or empty when no guess is usable.
%                Matching and assembly account for the initial event, waiting,
%                time caps and target frame. provenance.seed_screening reports
%                remaining timing/geometry mismatch; it is not validation.
%   diagnostics  Search diagnostics and selected candidate index. No NLP is
%                solved and no trajectories or files are stored.

if nargin < 2
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
[candidates, diagnostics] = orb2ds.find_legs(problem, options);
seed = [];
diagnostics.selected_candidate = [];
powered = strcmp(options.patching.method, 'powered');
order = 1:numel(candidates);
if powered
    [order, transfers] = orb2ds.internal.rank_powered_guesses(problem, candidates, options);
end
for index = order
    if powered
        transfer = transfers{index};
    else
        transfer = orb2ds.assemble_transfer(problem, candidates(index), options);
    end
    if ~isempty(transfer)
        seed = orb2ds.mesh_transfer(problem, transfer, options);
        if options.output.plot_initial_guess
            figure_handle = orb2ds.plot_initial_guess(transfer);
            if strcmp(figure_handle.Visible, 'on')
                drawnow;
            end
        end
        diagnostics.selected_candidate = index;
        return
    end
end
end
