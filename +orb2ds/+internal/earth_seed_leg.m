function [earth, success] = earth_seed_leg(problem, height, sample, angle, target_epoch, options)
%EARTH_SEED_LEG Construct one tangent Moon-Earth leg at a declared target epoch.
%
% PROTOTYPE:
%   [earth, success] = orb2ds.internal.earth_seed_leg(problem, height, sample, ...
%       angle, target_epoch, options)
% DESCRIPTION:
%   Select a perigee-circle sample for the outgoing target at target_epoch,
%   then solve a zero-revolution retrograde Lambert leg with tangent arrival.
% INPUT:
%   problem       Checked physical problem and target.
%   height        Earth-perigee altitude [km].
%   sample        Index in the patching.n_perigee perigee circle.
%   angle         Inertial lunar azimuth [rad].
%   target_epoch  Epoch for evaluation of the outgoing target [local days].
%   options       Resolved numerical options.
% OUTPUT:
%   earth    Compact inertial Lambert/perigee data [km, km/s, days], or [].
%   success  True only if a tangent Lambert leg was found.

model = problem.orbit.model;
target = orb2ds.internal.target_eci(problem.target, target_epoch);
[positions, velocities] = orb2ds.internal.rp_circle_from_vinfplus( ...
    target, model.earth_radius_km + height, model.gm_earth_km3_s2, options.patching.n_perigee);
radial = [cos(angle); sin(angle); 0];
transverse = [-sin(angle); cos(angle); 0];
position = model.distance_km * radial;
periapsis = positions(sample, :).';
[duration, initial, arrival, success] = ...
    orb2ds.internal.perigee_lambert(position, periapsis, model, options);
earth = [];
if ~success
    return
end
post = velocities(sample, :).';
outgoing = [dot(initial, radial); ...
    dot(initial, transverse) - model.velocity_km_s; initial(3)];
earth = struct('initial_position_km', position, 'initial_velocity_km_s', initial, ...
    'periapsis_position_km', periapsis, 'periapsis_velocity_pre_km_s', arrival, ...
    'delta_v_km_s', post - arrival, 'duration_days', duration, ...
    'moon_angle_rad', angle, 'outgoing_moon_asymptote_km_s', outgoing, ...
    'target_epoch_days', target_epoch);
end
