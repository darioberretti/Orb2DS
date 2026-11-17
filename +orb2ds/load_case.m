function [problem, options, output] = load_case(filename)
%LOAD_CASE Prepare scientific inputs and numerical options from one case file.
%
% PROTOTYPE:
%   [problem, options] = orb2ds.load_case(filename)
%   [problem, options, output] = orb2ds.load_case(filename)
%
% DESCRIPTION:
%   Invoke a MATLAB configuration function returning cfg. Resolve data paths
%   against that file, read explicitly declared MAT inputs, validate the
%   scientific request and complete numerical defaults. Does not propagate,
%   generate a database or execute an optimization. The temporary current-
%   directory change is restored on success and on error.
%
% INPUT:
%   filename  Path to a configuration .m function returning cfg with orbit
%             or files.orbit, target, optional constraints/options/output
%             blocks and optional files.database. See docs/CONTRACTS.md.
% OUTPUT:
%   problem   In-memory orbit, target, constraints and optional database.
%   options   Complete numerical options, ready for independent stage calls.
%   output    Optional saving settings: directory, filename and
%             overwrite_without_prompt. Relative directories resolve against
%             the configuration; default is Orb2DS_output beside that file.
%             No folder is created and no saving is authorized by load_case.

filename = char(filename);
[folder, name, extension] = fileparts(filename);
assert(strcmp(extension, '.m') && isfile(filename), 'orb2ds:Case', ...
    'Specify an existing MATLAB configuration function file.');
if isempty(folder)
    folder = pwd;
end
[status, attributes] = fileattrib(folder);
assert(status, 'orb2ds:Case', 'Cannot resolve the configuration directory.');
folder = attributes.Name;

% Function lookup uses the case directory without permanently changing path.
original_directory = pwd;
restore_directory = onCleanup(@() cd(original_directory));
cd(folder);
cfg = feval(name);
clear restore_directory

allowed = {'orbit', 'files', 'target', 'constraints', 'options', 'output'};
assert(isstruct(cfg) && isscalar(cfg), 'orb2ds:Case', 'The configuration must return cfg.');
unknown = setdiff(fieldnames(cfg), allowed);
assert(isempty(unknown), 'orb2ds:UnknownField', 'Unknown case block: %s.', strjoin(unknown, ', '));
if ~isfield(cfg, 'files')
    cfg.files = struct();
end
unknown = setdiff(fieldnames(cfg.files), {'orbit', 'database'});
assert(isempty(unknown), 'orb2ds:UnknownField', 'Unknown file reference: %s.', strjoin(unknown, ', '));
has_inline = isfield(cfg, 'orbit');
has_file = isfield(cfg.files, 'orbit');
assert(xor(has_inline, has_file), 'orb2ds:Case', ...
    'Specify exactly one of cfg.orbit and cfg.files.orbit.');
if has_inline
    problem.orbit = cfg.orbit;
else
    data = load(resolve_file(folder, cfg.files.orbit), 'orbit');
    problem.orbit = data.orbit;
end
problem.target = cfg.target;
if isfield(cfg, 'constraints')
    problem.constraints = cfg.constraints;
end
problem = orb2ds.internal.check_problem(problem);
supplied = struct();
if isfield(cfg, 'options')
    supplied = cfg.options;
end
options = orb2ds.internal.options(supplied, problem.constraints);
output = struct('directory', 'Orb2DS_output', 'filename', 'transfer_result.mat', ...
    'overwrite_without_prompt', false);
if isfield(cfg, 'output')
    output = orb2ds.internal.merge_options(output, cfg.output, 'output');
end
validateattributes(output.overwrite_without_prompt, {'logical'}, {'scalar'});
assert((ischar(output.directory) && isrow(output.directory)) || ...
    (isstring(output.directory) && isscalar(output.directory) && strlength(output.directory) > 0), ...
    'orb2ds:OutputPath', 'Specify a nonempty output directory.');
output.directory = char(output.directory);
if ~startsWith(output.directory, filesep) && ...
        isempty(regexp(output.directory, '^[A-Za-z]:[\\/]', 'once'))
    output.directory = fullfile(folder, output.directory);
end
assert((ischar(output.filename) && isrow(output.filename)) || ...
    (isstring(output.filename) && isscalar(output.filename) && strlength(output.filename) > 0), ...
    'orb2ds:OutputPath', 'Specify a nonempty output filename.');
output.filename = char(output.filename);
[parent, base, extension] = fileparts(output.filename);
assert(isempty(parent) && ~isempty(base) && strcmpi(extension, '.mat') && ...
    ~any(ismember(output.filename, '*?')), ...
    'orb2ds:OutputPath', 'The result filename must be a .mat name without a directory.');
if isfield(cfg.files, 'database')
    problem.database = orb2ds.load_orbit_moon_database( ...
        resolve_file(folder, cfg.files.database));
    orb2ds.internal.same_orbit(problem.orbit, problem.database.orbit);
end
end

function filename = resolve_file(folder, reference)
%RESOLVE_FILE Resolve a data file independently of the MATLAB current folder.
reference = char(reference);
is_absolute = startsWith(reference, filesep) || ...
    ~isempty(regexp(reference, '^[A-Za-z]:[\\/]', 'once'));
if is_absolute
    filename = reference;
else
    filename = fullfile(folder, reference);
end
assert(isfile(filename), 'orb2ds:MissingFile', 'Missing declared input: %s.', filename);
end
