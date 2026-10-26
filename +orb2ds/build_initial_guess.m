function [seed, diagnostics] = build_initial_guess(problem, supplied)
%BUILD_INITIAL_GUESS Compose matching, physical assembly and explicit meshing.
%
% PROTOTYPE:
%   [seed, diagnostics] = orb2ds.build_initial_guess(problem, options)
% INPUT:
%   problem/options  Same contracts as find_transfer.
% OUTPUT:
%   seed         First reconstructible ranked compact guess, or empty.
%   diagnostics  Search diagnostics and selected candidate index. No NLP is
%                solved and no trajectories or files are stored.

if nargin < 2
    supplied = struct();
end
[candidates, diagnostics] = orb2ds.find_legs(problem, supplied);
seed = [];
diagnostics.selected_candidate = [];
for index = 1:numel(candidates)
    transfer = orb2ds.assemble_transfer(problem, candidates(index), supplied);
    if ~isempty(transfer)
        seed = orb2ds.mesh_transfer(problem, transfer, supplied);
        diagnostics.selected_candidate = index;
        return
    end
end
end
