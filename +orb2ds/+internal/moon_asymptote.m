function [local_velocity, asymptotic_velocity] = moon_asymptote(states, model)
%MOON_ASYMPTOTE Distinguish local SOI velocity from an inbound Kepler asymptote.
%   Input states are Nx6 physical rotating rows. Velocities are Moon-relative
%   inertial vectors expressed in Moon RTH axes, in km/s. Nonhyperbolic
%   encounters retain their local velocity and have NaN asymptotic velocity.

position = states(:, 1:3) - [(1 - model.mu) * model.distance_km, 0, 0];
omega = 1 / (86400 * model.time_days);
local_velocity = states(:, 4:6) + ...
    omega * [-position(:, 2), position(:, 1), zeros(size(states, 1), 1)];
asymptotic_velocity = NaN(size(local_velocity));
for index = 1:size(states, 1)
    r = position(index, :);
    v = local_velocity(index, :);
    gm = model.gm_moon_km3_s2;
    energy = dot(v, v) / 2 - gm / norm(r);
    if energy <= 0
        continue
    end
    h = cross(r, v);
    e_vector = cross(v, h) / gm - r / norm(r);
    e = norm(e_vector);
    p = e_vector / e;
    if norm(h) == 0
        asymptotic_velocity(index, :) = sqrt(2 * energy) * v / norm(v);
    else
        q = cross(h / norm(h), p);
        asymptotic_velocity(index, :) = sqrt(2 * energy) * ...
            (p + sqrt(e^2 - 1) * q) / e;
    end
end
end
