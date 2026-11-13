function cfg = config_transfer()
%CONFIG_TRANSFER Find a transfer using this workspace's generated inputs.
%
% PROTOTYPE:
%   cfg = config_transfer()
%   [problem, options] = orb2ds.load_case('path/to/config_transfer.m')
%
% DESCRIPTION:
%   Run build_database.m first. Both MAT paths resolve against this file,
%   independently of the MATLAB current folder. For the complete annotated
%   transfer options, see examples/config_transfer.m in the Orb2DS installation.
%
% OUTPUT:
%   cfg  Orbit/database references, target, constraints, selected numerics and saving settings.

%% Inputs exported by build_database.m

% The orbit is an explicit input, shared through a file rather than a repeated seed.
cfg.files.orbit = fullfile('databases', 'orbit.mat');
cfg.files.database = fullfile('databases', 'orbit_moon.mat');
cfg.target.frame = 'eci';
cfg.target.vinf_km_s = [-2.0511679723998526; 1.4213996556899797; -0.1575143883070597];

%% Physical limits

cfg.constraints.initial_time_days = [];       % Free initial event epoch [local days].
cfg.constraints.initial_phase = [];           % Free initial event phase [0,1].
cfg.constraints.max_wait_time_days = 0;       % No waiting; [] or omission also means zero.
cfg.constraints.max_transfer_time_days = 50; % Flight cap [days].
cfg.constraints.max_total_time_days = [];     % No additional wait + flight cap.
cfg.constraints.min_earth_altitude_km = 1000;
cfg.constraints.min_moon_altitude_km = 100;
cfg.constraints.impulse_nodes = 'all';

%% Search, solver and inspection

% Modest search resolution; omitted options use the library defaults.
cfg.options.patching.n_perigee = 24;
cfg.options.patching.n_moon = 36;
cfg.options.patching.max_altitude_trials = 8;
cfg.options.solver.name = 'fmincon';           % Requires Optimization Toolbox.
cfg.options.solver.evaluation = 'matlab';
cfg.options.solver.display = 'iter';
% For IPOPT, add CasADi to MATLAB's path, then select name='ipopt' and
% evaluation='matlab' or 'casadi'. Numerical convergence is problem dependent.
cfg.options.output.display = true;
cfg.options.output.plot_initial_guess = true;
cfg.options.output.plot_nlp_guess = true;
cfg.options.validation.require_pass = false; % True selects by physically validated cost.
% Both settings compute and retain the physical diagnostics.

%% Explicit result saving, separate from numerical options

% Relative to THIS configuration; the folder is created when saving is prepared.
cfg.output.directory = 'Orb2DS_output';
cfg.output.filename = 'transfer_result.mat';
cfg.output.overwrite_without_prompt = false; % Ask before replacing an existing result.
% Set true for authorized unattended replacements. With false, batch execution
% raises an error on an existing file instead of waiting for a response.
end
