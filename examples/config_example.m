function cfg = config_example()
%CONFIG_EXAMPLE Complete, copyable configuration reference for orb2ds.
%
% PROTOTYPE:
%   cfg = config_example()
%   [problem, options] = orb2ds.load_case('path/to/config_example.m')
%
% DESCRIPTION:
%   Copy this file anywhere and edit it for your own scripts. If renaming the
%   file, rename this function too. Add Orb2DS to MATLAB's path first.
%   Every supported configuration field is shown below, with units and
%   interactions. Mutually exclusive alternatives are commented out. Active
%   values retain the runnable reduced Venus example; they are not universal
%   mission defaults. Configuration does not propagate, generate data or solve.
%
% OUTPUT:
%   cfg  Orbit/files, target, physical constraints and all numerical options.
%
% NOTES:
%   Physical constraints set to [] or omitted remain free. Omitted numerical
%   fields use orb2ds.defaults.numerical_options(); numerical [] is invalid.
%   Explicit zero is a value, not an instruction to use a default.

%% Model and departure orbit

% Primary constants determine all derived scales. Changing the model/orbit
% requires a matching catalogue; do not relabel the packaged database.
model_parameters.gm_earth_km3_s2 = 398600.433;                  % Earth GM [km^3/s^2].
model_parameters.gm_moon_km3_s2 = 398600.433 * 0.0121506683 / ...
    (1 - 0.0121506683);                                      % Moon GM [km^3/s^2].
model_parameters.distance_km = 384405;                       % Circular separation [km].
model_parameters.earth_radius_km = 6378;                     % Clearance reference [km].
model_parameters.moon_radius_km = 1738;                      % Clearance reference [km].
model_parameters.moon_angle_ref_rad = 0;                     % Lunar ECI azimuth at t=0.
model = orb2ds.earth_moon_model(model_parameters);

% Inline periodic orbit: barycentric rotating [x;y;z;vx;vy;vz], km and km/s.
% This reference is supplied normalized, then explicitly scaled once.
reference_nd = [-1.1377073434659586; 0; 0; 0; 1.9863955242330344; 0];
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
cfg.orbit.schema_version = 1;                                % Current descriptor schema.
cfg.orbit.state_ref = reference_nd .* scale;                 % Physical 6x1 seed.
cfg.orbit.period_days = 3.395596937863704 * model.time_days;  % Full orbit period [days].
cfg.orbit.model = model;                                    % Complete coherent model.
% cfg.orbit.provenance = struct('source', 'my orbit input');  % Optional metadata.

% ALTERNATIVE: replace the inline orbit with a MAT file containing 'orbit'.
% Exactly one of cfg.orbit and cfg.files.orbit must be supplied.
% cfg = rmfield(cfg, 'orbit');
% cfg.files.orbit = 'inputs/my_orbit.mat';

%% Reusable database

% Resolve the installed example asset independently of this file's location.
% This keeps an unchanged copy runnable from any directory. For your own
% archive, replace the assignment with an absolute path or a path relative
% to THIS configuration file, for example 'inputs/my_catalogue.mat'.
library_root = fileparts(fileparts(which('orb2ds.earth_moon_model')));
cfg.files.database = fullfile(library_root, 'data', 'orbit_moon_example.mat');

% find_transfer/find_legs require the database. A standalone optimize_transfer
% call does not: omit files.database when loading an optimization-only setup.
% Generation is a separate explicit build_orbit_moon_database call, never an
% automatic consequence of loading configuration or finding a transfer.

%% Outgoing Earth excess velocity

% Nonzero 3x1 vector [km/s], constant in the declared frame. ECI axes are the
% idealized axes of this model, not an automatically assigned J2000 frame.
cfg.target.frame = 'eci';                                   % 'eci' or 'earth_sun_rth'.
cfg.target.vinf_km_s = [-2.0511679723998526; 1.4213996556899797; -0.1575143883070597];

% ALTERNATIVE: replace the frame AND vector with the desired RTH components.
% R points Sun-to-Earth, T follows planar heliocentric motion, H is +Z.
% The solar angle below is Earth-to-Sun at local t=0. Specify the geometry
% explicitly; this adds neither ephemerides nor solar gravity. The target is
% enforced at the optimized final epoch; patching uses an epoch-zero snapshot.
% cfg.target.frame = 'earth_sun_rth';
% cfg.target.vinf_km_s = [2.4; 0.5; 0.1];
% cfg.target.solar_geometry.angle_ref_rad = 0.4;              % [rad].
% cfg.target.solar_geometry.rate_rad_day = 2 * pi / 365.25;  % [rad/day].

%% Physical constraints

% t=0 and phase=0 identify the seed reference, not fixed departure conditions.
cfg.constraints.initial_time_days = [];       % Initial event epoch [local days].
cfg.constraints.initial_phase = [];           % Initial event phase [0,1]; 1 maps to 0.
cfg.constraints.max_wait_time_days = [];      % Wait cap [days]; 0 forbids waiting.
cfg.constraints.max_transfer_time_days = 50;  % Departure -> Earth perigee cap [days].
cfg.constraints.max_total_time_days = [];     % Wait + flight cap [days].
cfg.constraints.min_earth_altitude_km = 1000; % Minimum altitude above Earth radius.
cfg.constraints.min_moon_altitude_km = 100;   % Minimum altitude above Moon radius.
cfg.constraints.impulse_nodes = 'all';        % 'all' or 'endpoints'; default 'all'.

% With an initial epoch/phase specified, waiting is nonnegative and advances
% td=t0+w and/or sd=mod(s0+w/T,1). A missing epoch/phase remains free. If both
% are absent, departure epoch/phase are independent variables, waiting has
% no earlier reference event, and total time equals flight time.
% All active caps intersect; none overrides another. For example total=40,
% flight=35, wait=10 still requires wait+flight<=40, not <=45. Numerical
% search horizons below do not become final mission-duration constraints.

% RESERVED, unsupported: leave empty. A scalar or [earliest,latest] final
% epoch requires the future final-time algorithm and currently raises an error.
cfg.constraints.final_time_days = [];
% Absolute MJD2000 epochs and automatic ephemeris geometry are not supported yet.

%% Integration and shooting mesh

cfg.options.integration.relative_tolerance = 1e-13; % ode113 relative tolerance.
cfg.options.integration.absolute_tolerance = 1e-14; % Normalized-state absolute tolerance.
cfg.options.mesh.max_step_days = 0.5;               % Maximum initial node spacing [days].
% Mesh construction retains event anchors. optimize_transfer never remeshes
% a supplied guess; change mesh settings before calling mesh_transfer.

%% Leg matching and patched-guess search

cfg.options.patching.n_perigee = 24;             % Perigee-circle samples; default 101.
cfg.options.patching.n_moon = 36;                % Lunar-angle samples; default 201.
cfg.options.patching.start_altitude_km = 1000;   % Search starting Earth altitude [km].
cfg.options.patching.altitude_factor = 1.1;      % Multiplicative altitude growth (>1).
cfg.options.patching.max_altitude_trials = 8;    % Search budget; default 80 trials.
cfg.options.patching.speed_tolerance_km_s = 0.05;% Lunar asymptotic-speed match tolerance.
cfg.options.patching.n_candidates = 10;         % Retained ranked matches; >= n_starts.
cfg.options.patching.lambert_tolerance = 1e-6;   % Tangency |v dot r|/(|v||r|), dimensionless.
cfg.options.patching.lambert_iterations = 60;    % Maximum bisection iterations.
cfg.options.patching.max_lambert_days = 20;      % Earth-leg search horizon [days].
cfg.options.patching.flyby_horizon_days = 5;     % Each finite-flyby integration horizon.
% Ranking uses estimated Earth-perigee burn, not final optimized total delta-v.
% The three reduced sampling/budget values above preserve the small example.

%% Native fmincon optimization

cfg.options.solver.run_feasibility = true;          % Zero-objective feasibility stage first.
cfg.options.solver.max_iterations_feasibility = 200;% Stage-1 iteration budget.
cfg.options.solver.max_iterations = 2000;           % Delta-v stage iteration budget.
cfg.options.solver.max_function_evaluations = 1000000; % Per-stage evaluation budget.
cfg.options.solver.minimum_segment_days = 1e-6;     % Positive numerical duration resolution.
cfg.options.solver.constraint_tolerance = 1e-6;    % Normalized NLP feasibility tolerance.
cfg.options.solver.optimality_tolerance = 1e-2;     % First-order stopping tolerance.
cfg.options.solver.step_tolerance = 1e-12;          % Solver step stopping tolerance.
cfg.options.solver.display = 'iter';               % 'off', 'final', 'iter', 'iter-detailed'.
% The algorithm is SQP; no alternate solver/objective is currently configured.
% Stage 1 displays objective zero. Stage 2 displays normalized total delta-v;
% multiply f(x) by model.velocity_km_s*1000 for m/s. The header prints this factor.
% A time cap incompatible with node count/minimum_segment_days is an error;
% choose a coarser mesh or smaller numerical duration resolution explicitly.

%% Independent physical validation

cfg.options.validation.position_tolerance_km = 0.001;      % Shooting position defects.
cfg.options.validation.velocity_tolerance_km_s = 1e-6;    % Velocity/radial-event residuals.
cfg.options.validation.target_tolerance_km_s = 1e-5;      % Achieved Earth excess velocity.
cfg.options.validation.altitude_tolerance_km = 0.001;     % Body-clearance tolerance.
cfg.options.validation.time_tolerance_days = 1e-7;        % Timing equalities/caps.
cfg.options.validation.orbit_closure_position_km = 0.01;  % Periodic-orbit position closure.
cfg.options.validation.orbit_closure_velocity_km_s = 1e-7;% Periodic-orbit velocity closure.
% Local shooting acceptance and chained propagation have separate flags.
% A solver success code alone does not establish a physically valid solution.

%% Optional multistart and automatic messages

cfg.options.n_starts = 1;                       % find_transfer only; deterministic matches.
cfg.options.output.display = true;             % Search, stages and physical summaries.
cfg.options.output.keep_attempt_solutions = false; % Keep compact per-start records too.
% solver.display is independent of output.display. Disable both for a silent
% library/solver. Explicit disp/fprintf calls in your script are unaffected.
% For automatic multistart n_candidates>=n_starts. The explicit step_by_step
% script instead chooses one candidate_index and calls optimize_transfer once.
% Dense trajectories are NEVER embedded in results, regardless of these flags.

%% Explicit database-generation grid

% Used ONLY by build_orbit_moon_database, not find_transfer/load_case.
% These are generic builder defaults, not the packaged catalogue's recipe:
% that smaller archive used 12 phases, 5 magnitudes, 12 azimuths and 50 days.
cfg.options.database.phases = (0:49) / 50;            % Normalized phases [0,1]; 1 maps to 0.
cfg.options.database.impulses_m_s = linspace(0, 50, 10); % Burn magnitudes [m/s].
cfg.options.database.azimuths_rad = (0:99) * 2 * pi / 100; % Rotating XY azimuths [rad].
cfg.options.database.elevations_rad = 0;             % Out-of-plane elevations [rad].
cfg.options.database.horizon_days = 85;              % Forward encounter search [days].
% Reusing an existing archive requires matching orbit, grid and integration
% settings. A mismatched existing filename raises an error; it is not replaced.

%% Separate reconstruction and plotting settings for your script

% These belong to their functions, not cfg/options or the transfer solver.
% All supported settings are listed here as copyable calls:
%
% trajectory = orb2ds.reconstruct_trajectory(result.solution, ...
%     struct('samples_per_segment', 50));           % Integer >=2; transient samples.
% figure_handle = orb2ds.plot_trajectory(trajectory, struct( ...
%     'visible', 'on', ...                         % 'on' or 'off'.
%     'frame', 'rotating', ...                     % 'rotating' [DU] or 'eci' [km].
%     'view', [0, 90], ...                         % XY; [-37.5,30] gives a 3D view.
%     'show_nodes', true, ...                      % Shooting-node circles.
%     'show_impulses', true, ...                   % Uniformly scaled burn arrows.
%     'impulse_scale', 0.38));                     % Longest arrow / trajectory span.
% Arrows keep relative magnitudes/directions; lengths are not displacements.
% Zero impulse_scale hides arrows. No call saves results/figures implicitly.
end
