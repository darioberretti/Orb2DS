# Explicit output files

Scientific calls return in-memory results. `load_case`, `find_transfer` and
`optimize_transfer` do not save results or create an output folder. A calling
script requests saving explicitly and prepares its destinations before starting
matching or optimization.

## Transfer configuration

The optional top-level block is separate from `cfg.options.output`, which
controls library messages, initial-guess plots and retained compact attempts:

```matlab
cfg.output.directory = 'Orb2DS_output';
cfg.output.filename = 'transfer_result.mat';
cfg.output.overwrite_without_prompt = false;
```

These are also the defaults when the block is omitted. `directory` is a
nonempty absolute path or a path relative to the configuration file. `filename`
is a `.mat` name without directory components. The overwrite setting is a
logical scalar. The directory belongs to the user's project; it is not derived
from the installed library path. Copy `examples/workspace/` to your project
before running its generation/saving scripts.

`[problem, options, output] = orb2ds.load_case(configuration_file)` resolves the
directory without creating it. The usual two-output call remains supported.

## Prepare before computing, save when ready

```matlab
[problem, options, output] = orb2ds.load_case(configuration_file);
destination = orb2ds.prepare_output(output.directory, output.filename, ...
    struct('overwrite_without_prompt', output.overwrite_without_prompt, ...
    'display', options.output.display));
if isempty(destination)
    return
end
result = orb2ds.find_transfer(problem, options);
orb2ds.save_output(destination, output.filename, struct('result', result));
```

With no existing file, preparation creates missing parent directories and
proceeds. With existing files and `overwrite_without_prompt=false`, it lists
the files and asks once. Only `y` or `yes`, case insensitive, authorizes saving;
an empty or negative response returns an empty destination. The calling script
must return before starting the numerical work. The question also names the
setting that disables further questions.

With `overwrite_without_prompt=true`, preparation announces the planned
replacements and proceeds. In MATLAB `-batch` mode, an existing file without
that authorization raises `orb2ds:OverwriteConfirmationRequired`; it never
waits for interactive input. New files do not require the flag in batch mode.

`prepare_output` accepts a cell or string vector of filenames to authorize
several files with one question. Its `display` setting defaults to true and
controls preparation, directory-creation and save messages. The confirmation
question is still required when ordinary messages are disabled. In direct
calls, a relative directory resolves against the current folder and [] selects
`./Orb2DS_output`; `load_case` has already resolved configuration-relative paths.

`save_output` writes the selected variables to a temporary MAT file in the
destination folder. It replaces the authorized output only after that write
completes. Before replacing, it compares the existing file with the exact bytes
recorded during preparation. A file created, removed or changed in the meantime
raises `orb2ds:OutputChanged` and is not replaced. The byte snapshots are temporary
in-memory data, separate from the saved result. Prepare again for a subsequent
save; authorization is not a permanent permission for a pathname.

Only fields explicitly passed in the variables structure are saved. Saving
`struct('result', result)` retains the compact transfer result. Trajectory
samples and figures remain separate objects and are not added automatically.

## Reusable inputs

Database generation is a separate operation. `build_orbit_moon_database` creates
missing parent folders at its explicitly supplied filename. An existing
compatible database is loaded; different orbit, grid or integration settings
raise an error and require another filename. The result-overwrite boolean
does not authorize replacement or regeneration of a database.

The example generation scripts also export `orbit.mat` once. An identical
existing orbit descriptor is reused without rewriting it; a different descriptor
requires another orbit filename. Generation and reuse report progress through
the database configuration's `options.output.display`.

The workspace's `databases/` and default `Orb2DS_output/` folders are generated
on demand and excluded by its `.gitignore`. If you choose another results folder
inside a version-controlled project, add it to that project's ignore rules.
