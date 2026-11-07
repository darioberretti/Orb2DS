function cfg = config_database()
%CONFIG_DATABASE Copyable orbit-Moon database generation configuration.
%
% PROTOTYPE:
%   cfg = config_database()
%
% DESCRIPTION:
%   Define the departure orbit, sampling grid, integration accuracy and output
%   paths for build_database.m. Copy this function anywhere; rename the function
%   if renaming the file. Add Orb2DS to MATLAB's path before calling it.
%   Calling configuration alone does not generate or load a database.
%
% OUTPUT:
%   cfg.orbit    Physical periodic-orbit descriptor.
%   cfg.output   Absolute database/standalone-orbit MAT destinations.
%   cfg.options  All settings used by build_orbit_moon_database.
%
% NOTES:
%   These settings define the catalogue, not optimized transfer constraints.
%   Omitted numerical settings inherit orb2ds.defaults.numerical_options().

%% Model and departure orbit

% Primary constants determine the normalized scales and encounter boundary.
model_parameters.gm_earth_km3_s2 = 398600.433;              % Earth GM [km^3/s^2].
model_parameters.gm_moon_km3_s2 = 398600.433 * 0.0121506683 / ...
    (1 - 0.0121506683);                                  % Moon GM [km^3/s^2].
model_parameters.distance_km = 384405;                    % Circular separation [km].
model_parameters.earth_radius_km = 6378;                  % Earth radius [km].
model_parameters.moon_radius_km = 1738;                   % Moon radius [km].
model_parameters.moon_angle_ref_rad = 0;                  % Lunar ECI azimuth at t=0 [rad].
model = orb2ds.earth_moon_model(model_parameters);

% Barycentric rotating [x;y;z;vx;vy;vz], scaled once into km and km/s.
reference_nd = [-1.1377073434659586; 0; 0; 0; 1.9863955242330344; 0];
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
cfg.orbit.schema_version = 1;
cfg.orbit.state_ref = reference_nd .* scale;
cfg.orbit.period_days = 3.395596937863704 * model.time_days;
cfg.orbit.model = model;
% cfg.orbit.provenance = struct('source', 'my orbit input'); % Optional metadata.

% ALTERNATIVE: replace cfg.orbit with a descriptor read from your MAT file.
% input = load(fullfile(fileparts(mfilename('fullpath')), 'inputs', 'orbit.mat'), 'orbit');
% cfg.orbit = input.orbit;

%% Output files

% Paths are anchored to THIS configuration, including when copied elsewhere.
% build_database.m creates parent folders and exports the same orbit separately
% for use as cfg.files.orbit in a transfer configuration.
folder = fileparts(mfilename('fullpath'));
cfg.output.database = fullfile(folder, 'databases', 'orbit_moon.mat');
cfg.output.orbit = fullfile(folder, 'databases', 'orbit.mat');
% An existing database is reused only with the same orbit, grid and integration
% settings. Choose another database filename after changing those inputs.
% The standalone orbit file is exported after successful creation or reuse.
% Database and orbit destinations must be distinct.

%% Departure sampling

% Every combination is propagated: 12 phases x 5 magnitudes x 12 azimuths
% x 1 elevation = 720 departures. Every inward lunar crossing is retained.
cfg.options.database.phases = (0:11) / 12;              % [0,1]; 1 wraps to 0. Default (0:49)/50.
cfg.options.database.impulses_m_s = [0, 10, 20, 30, 50]; % Finite magnitudes >=0 [m/s].
cfg.options.database.azimuths_rad = (0:11) * 2*pi/12;   % Finite XY azimuths [rad].
cfg.options.database.elevations_rad = 0;                % Finite elevation above XY [rad].
cfg.options.database.horizon_days = 50;                 % Positive propagation horizon [days].
% Grid fields are nonempty vectors, except the scalar horizon. Avoid repeated
% phase endpoints; zero-magnitude impulses repeat across direction samples.
% Defaults: 50 phases, 10 magnitudes from 0 to 50 m/s, 100 azimuths,
% elevation 0 and an 85-day horizon. This example deliberately uses a small grid.

%% Integration, orbit closure and progress

% Positive finite tolerances for normalized states; these are not km or km/s.
cfg.options.integration.relative_tolerance = 1e-12;
cfg.options.integration.absolute_tolerance = 1e-12;
% The orbit must close over one declared period within both physical limits.
cfg.options.validation.orbit_closure_position_km = 0.01;
cfg.options.validation.orbit_closure_velocity_km_s = 1e-7;
cfg.options.output.display = true;                      % Progress after each phase slice.
% Solver, mesh, target and mission-duration settings are not used for generation.
end
