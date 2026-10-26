function [duration, initial_velocity, final_velocity, success] = perigee_lambert(r1, r2, model, options)
%PERIGEE_LAMBERT Extract the thesis bracket/bisection search for a tangential arrival.
%   Positions are km, returned duration days and velocities km/s. The
%   historical retrograde Lambert branch is used. Failed searches are
%   explicitly excluded, not returned as tangential arrivals.

radius = norm(r2);
gm = model.gm_earth_km3_s2;
seed = max(1, norm(r1 - r2) / sqrt(gm)) / 86400;
scale = pi * sqrt((radius + model.distance_km)^3 / gm) / 86400;
maximum = options.patching.max_lambert_days;
low = min(seed, maximum);
[initial_velocity, final_velocity, ok] = orb2ds.internal.solve_lambert(r1, r2, low, gm);
duration = low;
success = false;
if ~ok
    return
end
g_low = dot(final_velocity, r2);
if abs(g_low) / (norm(final_velocity) * radius) <= options.patching.lambert_tolerance
    success = true;
    return
end

% Use the original longer-then-shorter bracket expansion.
bracketed = false;
for direction = [1, -1]
    step = scale / 2;
    for iteration = 1:9
        high = min(max(low + direction * step, 1 / 86400), maximum);
        [~, velocity_high, ok] = orb2ds.internal.solve_lambert(r1, r2, high, gm);
        if ok && sign(dot(velocity_high, r2)) ~= sign(g_low)
            bracketed = true;
            break
        end
        step = 2 * step;
    end
    if bracketed
        break
    end
end
if ~bracketed
    return
end
for iteration = 1:options.patching.lambert_iterations
    duration = (low + high) / 2;
    [initial_velocity, final_velocity, ok] = ...
        orb2ds.internal.solve_lambert(r1, r2, duration, gm);
    if ~ok
        return
    end
    residual = dot(final_velocity, r2);
    if abs(residual) / (norm(final_velocity) * radius) <= options.patching.lambert_tolerance
        success = true;
        return
    end
    if sign(residual) == sign(g_low)
        low = duration;
        g_low = residual;
    else
        high = duration;
    end
end
end
