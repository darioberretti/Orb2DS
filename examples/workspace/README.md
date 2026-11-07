# A project using Orb2DS

Copy this entire folder to your own working directory. It uses an installed
Orb2DS library and keeps generated inputs and results in the copied folder:

```text
my_project/
    config_database.m
    build_database.m
    config_transfer.m
    run_transfer.m
    databases/       (created during generation)
    Orb2DS_output/   (created when saving is prepared)
```

## Build the inputs

Add only the installed library root to MATLAB's path, then run the copied script:

```matlab
addpath('C:\path\to\Orb2DS');
run('C:\my_project\build_database.m');
```

Edit `config_database.m` to choose the periodic orbit and departure sampling.
The supplied small grid contains 12 phases, five impulse magnitudes and 12
in-plane directions, propagated for up to 50 days. Generation uses base MATLAB.
Its horizon limits catalogue generation, not the optimized transfer duration.

The script writes `databases/orbit_moon.mat` and the same orbit descriptor to
`databases/orbit.mat`. Running again reuses a compatible database; a mismatch
in orbit, grid or integration settings raises an error. Choose a new database
filename after changing those settings and update the transfer file references.
An identical standalone orbit file is reused without rewriting it; a different
descriptor requires another filename. Database and orbit destinations must be distinct.

## Find and inspect a transfer

Edit `config_transfer.m` to select the outgoing Earth excess velocity, physical
constraints and numerical controls. It reads the generated orbit and database,
so changing the orbit does not require maintaining a second copy of its seed.
Omitted numerical settings use library defaults; the full transfer reference
is `examples/config_transfer.m` in your Orb2DS installation.

```matlab
run('C:\my_project\run_transfer.m');
```

The supplied solver is fmincon and requires Optimization Toolbox. For IPOPT,
add your CasADi installation to the path, select `solver.name='ipopt'`, and
choose `solver.evaluation='matlab'` or `'casadi'` in the transfer configuration.
The configuration file controls library messages, native solver iterations,
and the two initial-guess figures independently.

`run_transfer.m` prints the status and physical checks, saves the compact
`result` to `Orb2DS_output/transfer_result.mat`, then reconstructs and plots the
returned solution or unvalidated candidate. `cfg.output.directory` selects
another destination, relative to config_transfer.m or absolute. Missing folders
are created automatically. No sampled trajectory or figure is saved inside it. An accepted
feasibility-stage result does not imply convergence of delta-v optimization;
inspect solver status and local/chained physical checks separately.

Before matching/optimization, the script checks its result filename. With
`cfg.output.overwrite_without_prompt=false` it asks before replacing an existing
file; answering no cancels the run. Set true to authorize unattended replacement.
In MATLAB -batch mode, false and an existing result raise an error before work
starts. The old result remains intact until the new MAT is ready. These settings
never authorize database replacement. See `docs/OUTPUT.md` in the installation
for direct saving calls and preparation of multiple files with one question.

Paths to generated inputs resolve against their configuration, and script
outputs resolve against the copied workspace. The scripts also work when
MATLAB's current folder is elsewhere; no Orb2DS examples folder is required
on the path. Generated databases/ and Orb2DS_output/ folders are excluded by
the workspace's .gitignore. Add custom destinations to your own ignore rules.
