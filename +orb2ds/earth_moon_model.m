function model = earth_moon_model(parameters)
%EARTH_MOON_MODEL Construct one consistent spatial Earth-Moon CR3BP model.
%
% PROTOTYPE:
%   model = orb2ds.earth_moon_model(parameters)
%
% DESCRIPTION:
%   Derive the mass ratio, circular angular rate and normalization from two
%   gravitational parameters and one primary separation. Defaults preserve
%   the reference orbit's mass ratio; its old, inconsistent time scales are
%   deliberately not reused. All declared angular origins refer to local t=0.
%
% INPUT:
%   parameters  Optional structure overriding primary constants below.
% OUTPUT:
%   model       Versioned model; lengths km, time days, velocities km/s.

if nargin == 0
    parameters = struct();
end
reference_mu = 0.0121506683;
primary = struct('gm_earth_km3_s2', 398600.433, ...
    'gm_moon_km3_s2', 398600.433 * reference_mu / (1 - reference_mu), ...
    'distance_km', 384405, 'earth_radius_km', 6378, ...
    'moon_radius_km', 1738, 'moon_angle_ref_rad', 0);
primary = orb2ds.internal.merge_options(primary, parameters, 'model');
names = fieldnames(primary);
for index = 1:numel(names)
    validateattributes(primary.(names{index}), {'double'}, {'real', 'finite', 'scalar'});
end
assert(all([primary.gm_earth_km3_s2, primary.gm_moon_km3_s2, ...
    primary.distance_km, primary.earth_radius_km, primary.moon_radius_km] > 0), ...
    'orb2ds:Model', 'Gravitational parameters, distance and radii must be positive.');

model = primary;
model.schema_version = 1;
model.name = 'earth_moon_cr3bp';
model.mu = primary.gm_moon_km3_s2 / ...
    (primary.gm_earth_km3_s2 + primary.gm_moon_km3_s2);
model.time_days = sqrt(primary.distance_km^3 / ...
    (primary.gm_earth_km3_s2 + primary.gm_moon_km3_s2)) / 86400;
model.velocity_km_s = primary.distance_km / (86400 * model.time_days);
model.encounter_radius_km = primary.moon_radius_km + primary.distance_km * ...
    (primary.gm_moon_km3_s2 / primary.gm_earth_km3_s2)^(2 / 5);
end
