function [impulse, jacobian] = impulse_map(u, swapped)
%IMPULSE_MAP Convert Oshima quadratic variables into a normalized impulse.
%   norm(impulse) = sum(u.^2). Values use normalized velocity units.
%   swapped selects the alternate x/y chart for a negative x burn.

u = u(:);
impulse = [u(1)^2 - u(2)^2 - u(3)^2; 2 * u(1) * u(2); 2 * u(1) * u(3)];
jacobian = 2 * [u(1), -u(2), -u(3); u(2), u(1), 0; u(3), 0, u(1)];
if swapped
    impulse = impulse([2, 1, 3]);
    jacobian = jacobian([2, 1, 3], :);
end
end
