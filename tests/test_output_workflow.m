function tests = test_output_workflow
%TEST_OUTPUT_WORKFLOW Exercise output preparation, authorization and preservation.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.restore_path = onCleanup(@() path(old_path));
directory = tempname;
mkdir(directory);
testCase.TestData.directory = directory;
testCase.TestData.remove_files = onCleanup(@() rmdir(directory, 's'));
end

function testCreateThenExplicitlyReplace(testCase)
directory = fullfile(testCase.TestData.directory, 'new', 'custom_results');
plan = orb2ds.prepare_output(directory, 'result.mat', struct('display', false));
filename = orb2ds.save_output(plan, 'result.mat', struct('answer', 1));
verifyEqual(testCase, load(filename), struct('answer', 1));

% Authorization never truncates the existing result before the new save.
plan = orb2ds.prepare_output(directory, 'result.mat', ...
    struct('display', false, 'overwrite_without_prompt', true));
verifyEqual(testCase, load(filename), struct('answer', 1));
orb2ds.save_output(plan, 'result.mat', struct('answer', 2));
verifyEqual(testCase, load(filename), struct('answer', 2));
verifyEqual(testCase, numel(dir(fullfile(directory, '*.mat'))), 1);
end

function testBatchRefusesUnapprovedReplacement(testCase)
assumeTrue(testCase, batchStartupOptionUsed, 'Batch-specific refusal check.');
directory = fullfile(testCase.TestData.directory, 'batch');
plan = orb2ds.prepare_output(directory, 'result.mat', struct('display', false));
filename = orb2ds.save_output(plan, 'result.mat', struct('answer', 7));
verifyError(testCase, @() orb2ds.prepare_output(directory, 'result.mat', ...
    struct('display', false)), 'orb2ds:OverwriteConfirmationRequired');
verifyEqual(testCase, load(filename), struct('answer', 7));
end

function testFilesChangedDuringWorkRemainUntouched(testCase)
directory = fullfile(testCase.TestData.directory, 'concurrent');
plan = orb2ds.prepare_output(directory, 'result.mat', struct('display', false));
filename = fullfile(directory, 'result.mat');
answer = ones(40, 1);
save(filename, 'answer');
verifyError(testCase, @() orb2ds.save_output(plan, 'result.mat', struct('answer', 2)), ...
    'orb2ds:OutputChanged');

plan = orb2ds.prepare_output(directory, 'result.mat', ...
    struct('display', false, 'overwrite_without_prompt', true));
answer = ones(80, 1);
save(filename, 'answer');
verifyError(testCase, @() orb2ds.save_output(plan, 'result.mat', struct('answer', 3)), ...
    'orb2ds:OutputChanged');
verifyEqual(testCase, load(filename), struct('answer', answer));
verifyEqual(testCase, numel(dir(fullfile(directory, '*.mat'))), 1);
end

function testOneConfirmationForMultipleFiles(testCase)
directory = fullfile(testCase.TestData.directory, 'interactive');
files = {'first.mat', 'second.mat'};
plan = orb2ds.prepare_output(directory, files, struct('display', false));
for index = 1:numel(files)
    orb2ds.save_output(plan, files{index}, struct('answer', index));
end

% Substitute only console input/detection; exercise the actual file workflow.
console = fullfile(testCase.TestData.directory, 'console');
mkdir(console);
write_function(fullfile(console, 'batchStartupOptionUsed.m'), ...
    sprintf('function value = batchStartupOptionUsed()\nvalue = false;\nend\n'));
write_function(fullfile(console, 'input.m'), sprintf([ ...
    'function answer = input(varargin)\n' ...
    'answer = getappdata(0, ''orb2ds_output_answer'');\n' ...
    'setappdata(0, ''orb2ds_output_questions'', getappdata(0, ''orb2ds_output_questions'')+1);\n' ...
    'end\n']));
old_path = path;
restore = onCleanup(@() restore_console(old_path));
addpath(console, '-begin');
clear input batchStartupOptionUsed
setappdata(0, 'orb2ds_output_questions', 0);
setappdata(0, 'orb2ds_output_answer', 'no');
declined = orb2ds.prepare_output(directory, files, struct('display', false));
verifyEmpty(testCase, declined);
verifyEqual(testCase, getappdata(0, 'orb2ds_output_questions'), 1);
verifyEqual(testCase, load(fullfile(directory, files{1})), struct('answer', 1));

setappdata(0, 'orb2ds_output_answer', 'yes');
accepted = orb2ds.prepare_output(directory, files, struct('display', false));
verifyEqual(testCase, getappdata(0, 'orb2ds_output_questions'), 2);
verifyEqual(testCase, load(fullfile(directory, files{2})), struct('answer', 2));
orb2ds.save_output(accepted, files{1}, struct('answer', 10));
orb2ds.save_output(accepted, files{2}, struct('answer', 20));
verifyEqual(testCase, load(fullfile(directory, files{1})), struct('answer', 10));
verifyEqual(testCase, load(fullfile(directory, files{2})), struct('answer', 20));
end

function write_function(filename, text)
%WRITE_FUNCTION Write a console substitute into the isolated test directory.
file = fopen(filename, 'w');
fprintf(file, '%s', text);
fclose(file);
end

function restore_console(old_path)
%RESTORE_CONSOLE Restore actual batch detection and console input after the check.
path(old_path);
clear input batchStartupOptionUsed
rmappdata(0, 'orb2ds_output_answer');
rmappdata(0, 'orb2ds_output_questions');
end
