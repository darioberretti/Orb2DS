function [velocity, energy_guard] = trial_asymptote(position, local_velocity, gm, requested_speed)
%TRIAL_ASYMPTOTE Evaluate escape velocity with a real C2 trial-state extension.
%
% INPUT:
%   position/local_velocity  Earth-centered inertial 3-vectors, normalized DU/VU.
%   gm                       Earth GM in normalized units.
%   requested_speed          Positive requested asymptotic speed [VU].
% OUTPUT:
%   velocity      Outgoing asymptote [VU] in the positive-energy domain.
%   energy_guard  Inequality <=0 keeping accepted states in that exact domain.
%
%   Below one percent of requested squared speed, a twice differentiable
%   rational extension keeps nonhyperbolic trials real. A positive-domain
%   inequality prevents these extended states from being accepted as roots.

r = position(:);
v = local_velocity(:);
radius = sqrt(sum(r.^2));
speed_squared = sum(v.^2) - 2 * gm / radius;
threshold = 0.01 * requested_speed^2;
z = (speed_squared - threshold) / threshold;
extension = sqrt(threshold) / (1 - z / 2 + 3 * z^2 / 8);
symbolic = isa(speed_squared, 'casadi.MX') || isa(speed_squared, 'casadi.SX');
if symbolic
    speed = if_else(speed_squared >= threshold, ...
        sqrt(fmax(speed_squared, threshold / 2)), extension);
elseif real(speed_squared) >= threshold
    speed = sqrt(speed_squared);
else
    speed = extension;
end
h = cross(r, v);
eccentricity = cross(v, h) / gm - r / radius;
e2 = sum(eccentricity.^2);
z = (e2 - 0.5) / 0.5;
extension = 0.5 / (1 - z + z^2);
if symbolic
    denominator = if_else(e2 >= 0.5, e2, extension);
elseif real(e2) >= 0.5
    denominator = e2;
else
    denominator = extension;
end
velocity = speed * (-eccentricity + speed * cross(h, eccentricity) / gm) / denominator;
energy_guard = (threshold - speed_squared) / threshold;
end
