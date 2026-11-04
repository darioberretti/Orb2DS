function [radial_speed, radial_acceleration] = radial_event(state, center, mu, derivative)
%RADIAL_EVENT CR3BP radial derivatives in normalized units, analytic in state.
%   Compute radial speed and acceleration relative to the supplied body center.
%   Nonconjugate products also permit complex-step derivative verification.
%   An optional state derivative permits the same algebra in a CasADi graph.

position = state(1:3) - center;
velocity = state(4:6);
if nargin < 4
    derivative = orb2ds.internal.rhs_CR3BP_3D(0, state, mu);
end
radius = sqrt(sum(position.^2));
product = sum(position .* velocity);
radial_speed = product / radius;
radial_acceleration = (sum(velocity.^2) + ...
    sum(position .* derivative(4:6))) / radius - product^2 / radius^3;
end
