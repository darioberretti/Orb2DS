function [cost, inbound_days, position, before, after] = powered_perilune( ...
    incoming, outgoing, gm, minimum, boundary, samples)
%POWERED_PERILUNE Find a common periapsis for two lunar hyperbolas.
%
%   [cost, inbound_days, r, v_pre, v_post] = powered_perilune( ...
%       incoming, outgoing, gm, minimum, boundary, samples)
%
%   Velocity rows [km/s] point along physical flight in a common inertial
%   basis. One outgoing row can be shared by all incoming rows. The search
%   uses logarithmically spaced radii inside the encounter sphere. For a
%   detailed single-pair result, refine the best sampled radius. Return impulse
%   magnitude [km/s], inbound time from the sphere [days] and optional
%   position and tangential velocities in the same basis [km, km/s].
%   Inf cost denotes an infeasible pair on the searched interval.

u = vecnorm(incoming, 2, 2);
w = vecnorm(outgoing, 2, 2);
first = incoming ./ u;
second = outgoing ./ w;
cosine = max(-1, min(1, sum(first .* second, 2)));

% The limiting coplanar radius satisfies
% asin(1/e_in) + asin(1/e_out) = separation. Bracket the physical root.
hi = repmat(boundary, size(u));
lo = repmat(minimum, size(u));
valid = u > 0 & w > 0 & all(isfinite(first), 2) & all(isfinite(second), 2);
valid = valid & clears_minimum_turn(boundary);
at_minimum = clears_minimum_turn(minimum);
bracket = find(valid & ~at_minimum);
iterations = 28;
if nargout > 2
    iterations = 48;
end
for iteration = 1:iterations
    mid = (lo(bracket) + hi(bracket)) / 2;
    fits = clears_minimum_turn(mid, bracket);
    hi(bracket(fits)) = mid(fits);
    lo(bracket(~fits)) = mid(~fits);
end
hi(at_minimum) = minimum;

radii = hi .* (boundary ./ hi) .^ linspace(0, 1, samples);
costs = evaluate(radii);
[cost, index] = min(costs, [], 2);
radius = radii(sub2ind(size(radii), (1:numel(u)).', index));
if nargout > 2 && isscalar(u) && isfinite(cost) && hi < boundary
    limits = radii([max(1, index - 1), min(samples, index + 1)]);
    if limits(1) < limits(2)
        [trial, trial_cost] = fminbnd(@evaluate, limits(1), limits(2), ...
            optimset('TolX', 1e-5));
        if trial_cost < cost
            radius = trial;
        end
    end
end
[cost, dot_in, dot_out, vp_in, vp_out] = evaluate(radius);
semimajor = gm ./ u.^2;
eccentricity = 1 + radius ./ semimajor;
anomaly = acosh(max(1, (1 + boundary ./ semimajor) ./ eccentricity));
inbound_days = sqrt(semimajor.^3 / gm) .* ...
    (eccentricity .* sinh(anomaly) - anomaly) / 86400;
if nargout <= 2
    return
end

% The two possible periapsis directions are reflections across the
% asymptote plane and have identical two-body impulse magnitudes.
has_geometry = isfinite(cost);
normal = cross(first, second + zeros(size(first)), 2);
sine = vecnorm(normal, 2, 2);
axis = normal ./ sine;
opposite = sine < 1e-12 & cosine < 0 & abs(dot_in + dot_out) < 1e-12;
if any(opposite)
    directions = first(opposite, :);
    [~, component] = min(abs(directions), [], 2);
    axes = eye(3);
    perpendicular = cross(directions, axes(component, :), 2);
    axis(opposite, :) = perpendicular ./ vecnorm(perpendicular, 2, 2);
end
along = (dot_out - cosine .* dot_in) ./ sine;
along(opposite) = 0;
radial = dot_in .* first + along .* cross(axis, first, 2) + ...
    sqrt(max(0, 1 - dot_in.^2 - along.^2)) .* axis;
position = radius .* radial;
before = vp_in .* (first - dot_in .* radial) ./ sqrt(1 - dot_in.^2);
after = vp_out .* (second - dot_out .* radial) ./ sqrt(1 - dot_out.^2);
cost = vecnorm(after - before, 2, 2);
cost(~has_geometry | ~isfinite(cost)) = Inf;

    function fits = clears_minimum_turn(radius, rows)
        % Bound the coplanar, same-tangent geometry at the smallest radius.
        if nargin < 2
            rows = 1:numel(u);
        end
        a = 1 ./ (1 + radius .* u(rows).^2 / gm);
        if isscalar(w)
            b = 1 ./ (1 + radius .* w.^2 / gm);
        else
            b = 1 ./ (1 + radius .* w(rows).^2 / gm);
        end
        fits = cosine(rows) - (sqrt((1 - a.^2) .* (1 - b.^2)) - a .* b) <= 8 * eps;
        % At the opposite asymptote the ordered radial projections coincide
        % only for equal speeds. Nearly opposite vectors also have an upper
        % feasibility condition, checked in evaluate.
    end

    function [value, a, b, vp1, vp2] = evaluate(radius)
        % The radial projections have opposite signs for ordered asymptotes.
        a = 1 ./ (1 + radius .* u.^2 / gm);
        b = -1 ./ (1 + radius .* w.^2 / gm);
        tangent = sqrt((1 - a.^2) .* (1 - b.^2));
        angle = (cosine - a .* b) ./ tangent;
        vp1 = sqrt(u.^2 + 2 * gm ./ radius);
        vp2 = sqrt(w.^2 + 2 * gm ./ radius);
        value = sqrt((vp2 - vp1).^2 + 2 * vp1 .* vp2 .* max(0, 1 - angle));
        value(abs(angle) > 1 + 1e-12 | ~valid) = Inf;
    end
end
