function destination = prepare_output(directory, filenames, supplied)
%PREPARE_OUTPUT Authorize output files and create their destination before a run.
%
% PROTOTYPE:
%   destination = orb2ds.prepare_output(directory, filenames, settings)
%
% DESCRIPTION:
%   Resolve a directory against the current folder, check all requested files
%   and ask once before replacing existing files. With no confirmation or a
%   negative response, no files are changed. Create missing parent folders
%   after authorization. Call before expensive numerical work.
%
% INPUT:
%   directory  Absolute/relative directory; [] selects ./Orb2DS_output.
%   filenames  One filename or a nonempty cell/string vector of filenames,
%              without directory components. Different formats can share a check.
%   settings   Optional struct: overwrite_without_prompt=false, display=true.
%              Both are logical scalars. Batch mode requires explicit overwrite
%              authorization if a requested file exists; it never waits for input.
% OUTPUT:
%   destination  File paths and temporary byte snapshots for save_output; [] when
%                the user declines. Existing files remain untouched until save.

if nargin < 3
    supplied = struct();
end
settings = orb2ds.internal.merge_options( ...
    struct('overwrite_without_prompt', false, 'display', true), supplied, 'output');
validateattributes(settings.overwrite_without_prompt, {'logical'}, {'scalar'});
validateattributes(settings.display, {'logical'}, {'scalar'});
if isempty(directory)
    directory = 'Orb2DS_output';
end
directory = char(directory);
assert(isrow(directory), 'orb2ds:OutputPath', 'Specify one output directory.');
if ~startsWith(directory, filesep) && isempty(regexp(directory, '^[A-Za-z]:[\\/]', 'once'))
    directory = fullfile(pwd, directory);
end
if ischar(filenames) || isstring(filenames)
    filenames = cellstr(filenames);
end
assert(iscellstr(filenames) && isvector(filenames) && ~isempty(filenames), 'orb2ds:OutputPath', ...
    'Specify a nonempty list of output filenames.');
destination = struct('directory', directory, 'files', {cell(size(filenames))}, ...
    'initial', {cell(size(filenames))}, 'display', settings.display);
existing = {};
for index = 1:numel(filenames)
    name = filenames{index};
    [folder, base] = fileparts(name);
    assert(isempty(folder) && ~isempty(base) && ~ismember(name, {'.', '..'}) && ...
        ~any(ismember(name, '*?')), ...
        'orb2ds:OutputPath', 'Output filenames must not contain directory components.');
    filename = fullfile(directory, name);
    assert(~isfolder(filename), 'orb2ds:OutputPath', 'An output filename names a directory: %s.', filename);
    destination.files{index} = filename;
    destination.initial{index} = orb2ds.internal.output_file_state(filename);
    if isfile(filename)
        existing{end+1} = filename;
    end
end
assert(numel(unique(lower(string(destination.files)))) == numel(filenames), ...
    'orb2ds:OutputPath', 'Output filenames must be distinct.');

% Confirmation covers the listed files, not future changes made by another run.
if ~isempty(existing)
    if ~settings.overwrite_without_prompt
        message = sprintf('  %s\n', existing{:});
        guidance = 'Set overwrite_without_prompt = true to authorize replacement without asking.';
        assert(~batchStartupOptionUsed, 'orb2ds:OverwriteConfirmationRequired', ...
            'Output files already exist:\n%s%s Batch execution cannot ask for confirmation.', message, guidance);
        fprintf('These files will be replaced only when new outputs are ready:\n%s%s\n', message, guidance);
        answer = input('Overwrite these files? [y/N]: ', 's');
        if ~any(strcmpi(strtrim(answer), {'y', 'yes'}))
            fprintf('Output cancelled; numerical work has not started.\n');
            destination = [];
            return
        end
    elseif settings.display
        fprintf('Replacement authorized for:\n');
        fprintf('  %s\n', existing{:});
    end
end
if ~isfolder(directory)
    [ok, message] = mkdir(directory);
    assert(ok, 'orb2ds:OutputDirectory', 'Cannot create output directory: %s', message);
    if settings.display
        fprintf('Created output directory: %s\n', directory);
    end
end
if settings.display
    fprintf('Prepared output files:\n');
    fprintf('  %s\n', destination.files{:});
end
end
