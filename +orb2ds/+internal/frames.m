function output = frames(states, time_days, model, direction)
%FRAMES Convert physical barycentric rotating and Earth-centered inertial states.
%
% INPUT:
%   states     Nx6 rows [position km, velocity km/s].
%   time_days  Scalar or Nx1 local epochs [days].
%   model      Canonical CR3BP model, including its angular origin.
%   direction  'to_eci' or 'to_rotating'.
% OUTPUT:
%   output     Nx6 rows in the destination frame, with the same physical units.
%   Implements the source rot2in/in2rot translation and omega-cross-r terms
%   with one consistent model angular rate and one declared inertial origin.

angle = time_days(:) / model.time_days + model.moon_angle_ref_rad;
if isscalar(angle)
    angle = repmat(angle, size(states, 1), 1);
end
omega = 1 / (86400 * model.time_days);
c = cos(angle);
s = sin(angle);
if strcmp(direction, 'to_eci')
    position = states(:, 1:3) + [model.mu * model.distance_km, 0, 0];
    velocity = states(:, 4:6) + omega * [-position(:, 2), position(:, 1), ...
        zeros(size(position, 1), 1)];
    output = [rotate(position, c, s), rotate(velocity, c, s)];
else
    assert(strcmp(direction, 'to_rotating'), 'orb2ds:Frame', 'Unknown frame conversion.');
    position = rotate(states(:, 1:3), c, -s);
    velocity = rotate(states(:, 4:6), c, -s) - ...
        omega * [-position(:, 2), position(:, 1), zeros(size(position, 1), 1)];
    output = [position - [model.mu * model.distance_km, 0, 0], velocity];
end
end

function output = rotate(input, c, s)
%ROTATE Apply the epoch-dependent planar rotation to each row.
output = [c .* input(:, 1) - s .* input(:, 2), ...
    s .* input(:, 1) + c .* input(:, 2), input(:, 3)];
end
