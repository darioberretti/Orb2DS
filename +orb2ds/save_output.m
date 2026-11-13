function filename = save_output(destination, name, variables)
%SAVE_OUTPUT Save explicitly selected MAT variables after output preparation.
%
% PROTOTYPE:
%   filename = orb2ds.save_output(destination, name, variables)
%
% DESCRIPTION:
%   Write a temporary MAT file beside the destination, then replace the
%   authorized file after the new MAT is complete. Refuse files created or
%   changed since prepare_output, comparing their exact bytes.
%   A failed serialization leaves the existing output untouched.
%
% INPUT:
%   destination  Nonempty plan returned by orb2ds.prepare_output before the run.
%   name         Filename listed in that plan, with extension .mat.
%   variables    Scalar struct whose fields become MAT variables. For a compact
%                transfer result, pass struct('result', result); sampled
%                trajectories/figures are not added automatically.
% OUTPUT:
%   filename     Absolute saved MAT path. Prepare a new plan for each execution.

assert(isstruct(destination) && isscalar(destination), 'orb2ds:OutputPlan', ...
    'Prepare and authorize output files before saving.');
validateattributes(variables, {'struct'}, {'scalar'});
filename = fullfile(destination.directory, char(name));
index = find(strcmp(filename, destination.files), 1);
assert(~isempty(index), 'orb2ds:OutputPlan', 'This filename was not prepared: %s.', filename);
[~, ~, extension] = fileparts(filename);
assert(strcmpi(extension, '.mat'), 'orb2ds:OutputPath', 'save_output writes .mat files.');

temporary = [tempname(destination.directory), '.mat'];
cleanup = onCleanup(@() remove_temporary(temporary));
save(temporary, '-struct', 'variables', '-v7.3');
assert(~isfolder(filename) && isequal(orb2ds.internal.output_file_state(filename), ...
    destination.initial{index}), 'orb2ds:OutputChanged', ...
    'Output changed after preparation; refusing to replace it: %s.', filename);
[ok, message] = movefile(temporary, filename, 'f');
assert(ok, 'orb2ds:OutputWrite', 'Could not save output: %s', message);
if destination.display
    fprintf('\n[Orb2DS] Saved data\n\n');
    fprintf('  Storage                        : MAT file\n');
    fprintf('  File                           : %s\n', filename);
    fprintf('  MAT variables                  : %s\n', strjoin(fieldnames(variables), ', '));
    if isfield(variables, 'result') && isstruct(variables.result) && isscalar(variables.result) && ...
            isfield(variables.result, 'solution') && isfield(variables.result, 'candidate')
        if ~isempty(variables.result.solution)
            fprintf('  Transfer record                : result.solution\n');
        elseif ~isempty(variables.result.candidate)
            fprintf('  Transfer record                : result.candidate\n');
        else
            fprintf('  Transfer record                : NONE\n');
        end
        fprintf('  Load in MATLAB                 : load(''%s'', ''result'')\n', strrep(filename, '''', ''''''));
        fprintf('  Node table                     : nodes = orb2ds.node_table(result);\n');
        fprintf('  Open table                     : openvar(''nodes'');\n');
        fprintf('  Full report                    : orb2ds.print_result(result);\n');
    end
end
end

function remove_temporary(filename)
%REMOVE_TEMPORARY Remove an unfinished save without touching its destination.
if isfile(filename)
    delete(filename);
end
end
