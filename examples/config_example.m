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
%   fields use orb2ds.defaults.numerical_options(). Optional solver constraint
%   tolerances accept [] to inherit the corresponding validation tolerance.
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

% Must be empty or omitted: nonempty final-epoch constraints are unsupported.
cfg.constraints.final_time_days = [];
% Epochs use local days; MJD2000 and automatic ephemeris geometry are unsupported.

%% Integration and shooting mesh

% Integration tolerances control the numerical propagation, not node spacing.
% States are integrated in normalized distance and velocity units; these are
% not tolerances in km or km/s. Both values must be positive finite scalars.
% ode113 uses them for MATLAB propagation; CVODES uses them in the symbolic
% solver unless overridden by options.solver.cvodes below.
cfg.options.integration.relative_tolerance = 1e-12; % Relative integration tolerance [-].
cfg.options.integration.absolute_tolerance = 1e-12; % Absolute normalized-state tolerance [-].

% mesh_transfer chooses the node count from a maximum time spacing [days].
% The count also depends on arc lengths and required event/boundary nodes.
cfg.options.mesh.max_step_days = 0.5;              % Positive finite maximum initial step.

% One refinement interval uses a smaller maximum step. BOTH from and to
% accept any of these named events in the assembled transfer:
%   'departure'       : departure from the supplied periodic orbit.
%   'moon_entry'      : inward crossing of model.encounter_radius_km from the Moon.
%   'moon_periapsis'  : lunar closest-approach anchor of the assembled guess.
%   'moon_exit'       : outward crossing of the same lunar encounter boundary.
%   'earth_periapsis' : final Earth-perigee arrival.
% These are event names, not node indices. Numeric node-index anchors and
% arbitrary interior-node selection are not supported for refinement.
cfg.options.mesh.refinement.from = 'moon_periapsis'; % Start anchor; choose an event above.
cfg.options.mesh.refinement.from_offset_days = -1;  % Signed offset from the start anchor [days].
cfg.options.mesh.refinement.to = 'earth_periapsis';  % End anchor; choose an event above.
cfg.options.mesh.refinement.factor = 3;             % Finite factor >=1; local step = 0.5/3 days.

% start = time(from) + from_offset_days; end = time(to).
% An offset of -1 starts one day BEFORE from; 0 starts AT from; +1 starts
% one day AFTER from. The end event has no offset setting.
% factor=1 disables refinement; factor=3 divides the maximum step by three.
% Generic library defaults: maximum step 0.5 days and factor 1.
% Examples (uncomment to replace the start/end settings above):
% cfg.options.mesh.refinement.from = 'moon_entry';
% cfg.options.mesh.refinement.from_offset_days = 0; % Start exactly at lunar entry.
% cfg.options.mesh.refinement.to = 'moon_exit';     % Refine only the lunar passage.
% cfg.options.mesh.refinement.factor = 1;          % Use the global spacing everywhere.
%
% An active interval must be nonempty and entirely inside the transfer.
% Out-of-range or reversed intervals raise an error; offsets are not clipped.
% Departure, lunar entry/periapsis/exit, Earth arrival and active refinement
% boundaries are retained exactly. Their insertion can make steps smaller
% than the requested maximum. Steps below solver.minimum_segment_days fail.
% optimize_transfer preserves the supplied node count and order. It can
% change segment durations, so max_step_days bounds only the INITIAL mesh.

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
% n_perigee, n_moon and max_altitude_trials control the search cost.

%% Optimization solver and evaluation route

cfg.options.solver.name = 'fmincon';                % 'fmincon' or 'ipopt'.
cfg.options.solver.evaluation = 'matlab';           % 'matlab' or 'casadi'.
% Supported pairs: fmincon/matlab, ipopt/matlab, ipopt/casadi. Both IPOPT
% routes require CasADi with its IPOPT plugin on the MATLAB path. Install it
% separately and addpath its root in your script, before calling the solver.
% 'matlab': ode113 + analytic state-transition/complex-step Jacobians.
% 'casadi': symbolic equations + CVODES sensitivities, only with IPOPT.

cfg.options.solver.run_feasibility = false;          % Zero-objective feasibility stage first.
cfg.options.solver.max_iterations_feasibility = 200;% Stage-1 iteration budget.
cfg.options.solver.max_iterations = 2000;           % Delta-v stage iteration budget.
cfg.options.solver.max_function_evaluations = 1000000; % fmincon-only evaluation budget.
cfg.options.solver.minimum_segment_days = 1e-6;     % Positive numerical duration resolution.
cfg.options.solver.constraint_tolerance = 1e-10;    % Scaled residual stopping threshold; default 1e-12.
cfg.options.solver.optimality_tolerance = 1e-2;     % fmincon optimality / IPOPT scaled NLP tol.
cfg.options.solver.step_tolerance = 1e-12;          % fmincon only; no IPOPT equivalent.
cfg.options.solver.display = 'iter';               % 'off', 'final', 'iter', 'iter-detailed'.
cfg.options.solver.fmincon.algorithm = 'sqp';       % Also interior-point, active-set, sqp-legacy.
cfg.options.solver.fmincon.options = struct();      % Native optimoptions names/values.
cfg.options.solver.ipopt = struct();                % Native IPOPT names/values.
cfg.options.solver.casadi = struct();               % Native nlpsol options, excluding ipopt.
cfg.options.solver.cvodes = struct();               % Native CVODES integrator options.
% Examples (uncomment as needed); native values override common settings.
% cfg.options.solver.fmincon.options.MaxIterations = 400;
% cfg.options.solver.ipopt.mu_strategy = 'adaptive';
% cfg.options.solver.ipopt.max_iter = 400;          % Overrides BOTH stage budgets.
% cfg.options.solver.ipopt.print_level = 5;         % Overrides common display mapping.
% cfg.options.solver.casadi.print_time = true;
% cfg.options.solver.cvodes.max_num_steps = 200000;
% Inactive native blocks are retained but not applied. Only plain data is
% accepted: callbacks/objects remain internal. Native typos fail at the solver.
% IPOPT defaults: limited-memory Hessian, acceptable_iter=0, no bound relaxation,
% no implicit ipopt.opt file. Exact Hessians require the symbolic route.
% display: off -> IPOPT level 0; final -> level 0 + final status;
% iter -> level 5; iter-detailed -> level 7. output.display is independent.
% Common tolerances have different solver meanings; validation is unchanged.
% A scaled residual of 1e-9 represents one effective solver constraint tolerance.
% The default constraint_tolerance=1e-12 targets 0.001 of each tolerance. This
% dimensionless stopping threshold is separate from validation thresholds.
% Native overrides can change stopping behavior, but never acceptance budgets.
% CVODES overrides affect symbolic optimization only. Independent physical
% validation always uses ode113 with options.integration tolerances.
% Stage 1 displays objective zero. Stage 2 displays normalized total delta-v;
% multiply f(x) by model.velocity_km_s*1000 for m/s. The header prints this factor.
% A time cap incompatible with node count/minimum_segment_days is an error;
% choose a coarser mesh or smaller numerical duration resolution explicitly.

%% Independent physical validation

% Always-active acceptance thresholds for independent ode113 propagation.
% Vector errors use Euclidean norms, not separate Cartesian axes. All values
% must be positive finite scalars; solver constraint settings do not change them.
% Position covers segment/departure/chained errors and altitude shortfall.
% Velocity covers segment/departure/chained errors, target, radial speed and
% impulse policy. Time covers timing equalities and waiting/flight/total caps.
cfg.options.validation.position_km = 1e-3;    % 1 m.
cfg.options.validation.velocity_km_s = 1e-6;  % 1 mm/s.
cfg.options.validation.time_days = 1e-7;      % Local days.

% Check the supplied orbit over one period; optimization cannot repair its
% reference state or period. These thresholds also apply during database building.
cfg.options.validation.orbit_closure_position_km = 0.01;  % One-period position closure [km].
cfg.options.validation.orbit_closure_velocity_km_s = 1e-7;% One-period velocity closure [km/s].
% Altitude tolerance allows a numerical shortfall from the mission minimum;
% the physical minimum itself is set in cfg.constraints.
% result.validation.tolerances reports the thresholds used. result.solution
% requires BOTH local and chained checks to pass; otherwise inspect candidate.

%% Solver constraint tolerances

% Physical residual scales used ONLY during optimization. [] inherits the
% corresponding validation tolerance above. A nonempty value applies immediately
% as min(validation,value), without an enable flag; it can only tighten the scale.
% All nonempty values must be positive finite scalars in the indicated units.
cfg.options.solver.constraint_tolerances.dynamics.position_km = [];   % Per-segment position defect [km].
cfg.options.solver.constraint_tolerances.dynamics.velocity_km_s = []; % Per-segment velocity defect [km/s].
cfg.options.solver.constraint_tolerances.departure.position_km = []; % Departure-to-orbit position [km].
cfg.options.solver.constraint_tolerances.departure.velocity_km_s = []; % Departure-to-orbit velocity [km/s].
cfg.options.solver.constraint_tolerances.target.velocity_km_s = [];  % Outgoing Earth vector error [km/s].
cfg.options.solver.constraint_tolerances.periapsis.radial_velocity_km_s = []; % Event radial speed [km/s].
cfg.options.solver.constraint_tolerances.clearance.altitude_km = []; % Node radius shortfall [km].
cfg.options.solver.constraint_tolerances.time_days = [];             % Timing equalities and duration caps [days].
% Example: dynamics.position_km=1e-4 requests a 10 cm solver scale while
% validation still accepts 1 m, including for the chained endpoint error.
% Equalities remain zero and mission limits are unchanged. The actual residual
% stopping threshold also depends on solver.constraint_tolerance, as above.
% result.constraint_tolerances reports all effective solver scales.

%% Optional multistart and automatic messages

cfg.options.n_starts = 1;                       % find_transfer only; deterministic matches.
cfg.options.output.display = true;             % Search, stages and physical summaries.
cfg.options.output.keep_attempt_solutions = false; % Keep compact per-start records too.
cfg.options.output.plot_initial_guess = true;  % Assembled physical legs, without shooting nodes.
cfg.options.output.plot_nlp_guess = true;      % Exact NLP initial vector, CR3BP arcs and gaps.
% Both plot flags default to false in the library and are independent of
% output.display/solver.display. find_transfer plots each attempted start.
% build_initial_guess honors the first flag; optimize_transfer honors the
% second. mesh_transfer and transcribe_guess themselves create no figures.
% solver.display is independent of output.display. Disable both for a silent
% library/solver. Explicit disp/fprintf calls in your script are unaffected.
% For automatic multistart n_candidates>=n_starts. The explicit step_by_step
% script instead chooses one candidate_index and calls optimize_transfer once.
% Dense trajectories are NEVER embedded in results, regardless of these flags.

%% Explicit database-generation grid

% Used ONLY by build_orbit_moon_database, not find_transfer/load_case.
% Small runnable grid: 12 phases x 5 magnitudes x 12 azimuths = 720 departures.
% Sampling matches the packaged example; integration uses the current options
% above, so the generated file is not claimed to be byte-identical to it.
cfg.options.database.phases = (0:11) / 12;           % Normalized phases; default (0:49)/50.
cfg.options.database.impulses_m_s = [0, 10, 20, 30, 50]; % Magnitudes [m/s]; default 10 values.
cfg.options.database.azimuths_rad = (0:11) * 2 * pi / 12; % XY azimuths [rad]; default 100 values.
cfg.options.database.elevations_rad = 0;             % Out-of-plane elevations [rad].
cfg.options.database.horizon_days = 50;              % Forward horizon [days]; default 85.
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
%     'impulse_scale', 0.38, ...                   % Longest arrow / trajectory span.
%     'show_defects', true));                     % Dashed propagated-end -> node gaps.
% assembled_figure = orb2ds.plot_initial_guess(transfer, [], ...
%     struct('samples_per_arc', 200, 'frame', 'rotating'));
% nlp_guess = orb2ds.transcribe_guess(problem, seed, options);
% nlp_trajectory = orb2ds.reconstruct_trajectory(nlp_guess);
% nlp_figure = orb2ds.plot_trajectory(nlp_trajectory, struct('show_defects', true));
% These explicit calls allow custom views without changing solver inputs.
% Arrows keep relative magnitudes/directions; lengths are not displacements.
% Zero impulse_scale hides arrows. No call saves results/figures implicitly.
end
