function [velocity, energy] = outgoing_asymptote(position, local_velocity, gm)
%OUTGOING_ASYMPTOTE Recover the achieved outgoing Kepler asymptote independently.
%   Earth-centered inertial positions are km, velocities km/s, GM km^3/s^2.
%   The eccentricity-vector construction also works away from periapsis.
%   Nonhyperbolic or radial singular states have no accepted escape vector.

r = position(:);
v = local_velocity(:);
energy = dot(v, v) / 2 - gm / norm(r);
velocity = NaN(3, 1);
h = cross(r, v);
if energy <= 0 || norm(h) == 0
    return
end
e_vector = cross(v, h) / gm - r / norm(r);
eccentricity = norm(e_vector);
if eccentricity <= 1
    return
end
p = e_vector / eccentricity;
q = cross(h / norm(h), p);
velocity = sqrt(2 * energy) * ...
    (-p + sqrt(eccentricity^2 - 1) * q) / eccentricity;
end
