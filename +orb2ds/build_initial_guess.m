function [seed, diagnostics] = build_initial_guess(problem, supplied)
%BUILD_INITIAL_GUESS Compose matching, physical assembly and explicit meshing.
%
% PROTOTYPE:
%   [seed, diagnostics] = orb2ds.build_initial_guess(problem, options)
% DESCRIPTION:
%   Skip guesses whose timelines cannot fit the requested mesh refinement.
%   Report the interval error if every assembled guess fails for this reason.
% INPUT:
%   problem/options  Same contracts as find_transfer.
% OUTPUT:
%   seed         Lowest weighted-cost powered guess or first usable
%                natural match, or empty when no guess is usable.
%                Matching and assembly account for the initial event, waiting,
%                time caps and target frame. provenance.seed_screening reports
%                remaining timing/geometry mismatch; it is not validation.
%   diagnostics  Search diagnostics and selected candidate index. No NLP is
%                solved and no trajectories or files are stored.

if nargin < 2
    supplied = struct();
end
problem = orb2ds.internal.check_problem(problem);
options = orb2ds.internal.options(supplied, problem.constraints);
[next_guess, diagnostics] = orb2ds.internal.prepare_guesses(problem, options);
[seed, transfer, diagnostics.selected_candidate] = next_guess();
if ~isempty(seed) && options.output.plot_initial_guess
    figure_handle = orb2ds.plot_initial_guess(transfer);
    if strcmp(figure_handle.Visible, 'on')
        drawnow;
    end
end
end
