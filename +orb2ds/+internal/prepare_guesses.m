function [next_guess, diagnostics] = prepare_guesses(problem, options)
%PREPARE_GUESSES Return a function that assembles and meshes the next usable match.
%
%   The powered shortlist is assembled once for ranking. Natural matches
%   are assembled when requested. Each call returns a seed, its assembled
%   transfer and the original match index. Empty outputs mark exhaustion.

[candidates, diagnostics] = orb2ds.find_legs(problem, options);
powered = strcmp(options.patching.lunar_flyby_matching_policy, 'powered');
order = 1:numel(candidates);
if powered
    [order, transfers] = orb2ds.internal.rank_powered_guesses(problem, candidates, options);
end
position = 1;
has_seed = false;
mesh_failure = [];
next_guess = @take_next;

    function [seed, transfer, index] = take_next()
        while position <= numel(order)
            index = order(position);
            position = position + 1;
            if powered
                transfer = transfers{index};
            else
                transfer = orb2ds.assemble_transfer(problem, candidates(index), options);
            end
            if isempty(transfer)
                print_skip('assembly', index, 'no assembled finite lunar passage');
                continue
            end

            try
                seed = orb2ds.mesh_transfer(problem, transfer, options);
            catch failure
                if ~strcmp(failure.identifier, 'orb2ds:MeshInterval')
                    rethrow(failure);
                end
                mesh_failure = failure;
                print_skip('mesh', index, failure.message);
                continue
            end
            has_seed = true;
            return
        end

        if ~has_seed && ~isempty(mesh_failure)
            rethrow(mesh_failure);
        end
        seed = [];
        transfer = [];
        index = [];
    end

    function print_skip(stage, index, detail)
        if options.output.display
            fprintf('\n[Orb2DS] Candidate %s\n\n', stage);
            fprintf('  Candidate                      : %d\n', index);
            fprintf('  Outcome                        : SKIPPED -- %s\n', detail);
        end
    end
end
