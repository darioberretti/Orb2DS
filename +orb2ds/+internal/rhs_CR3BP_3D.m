function [dxdt] = rhs_CR3BP_3D(~,xx, mu)
%RHS_CR3BP_3D Evaluate the 3D CR3BP state derivative.
%
% PROTOTYPE:
%   dxdt = rhs_CR3BP_3D(t, xx, mu)
%
% DESCRIPTION:
%   Evaluate normalized dynamics in the rotating barycentric frame, with
%   primaries at x = -mu and x = 1 - mu. Positions use DU, velocities VU,
%   and derivatives are taken with respect to time in TU.
%
% INPUT:
%   t     Scalar time [TU]; unused because the CR3BP is autonomous.
%   xx    [6 x 1] State [x; y; z; vx; vy; vz].
%   mu    Secondary-to-total mass ratio [-].
%
% OUTPUT:
%   dxdt  [6 x 1] State derivative, in input order.

    % Read rotating-frame coordinates and velocities.
    x  = xx(1);
    y  = xx(2);
    z  = xx(3);
    vx = xx(4);
    vy = xx(5);

    % Compute distances to the two primaries.
    r1 = sqrt((x + mu)^2 + y^2 + z^2);
    r2 = sqrt((x + mu - 1)^2 + y^2 + z^2);

    % Evaluate the effective-potential gradient.
    dUdx = x - (1-mu)/r1^3*(mu+x) + mu/r2^3*(1-mu-x);
    dUdy = y - (1-mu)/r1^3*y - mu/r2^3*y;
    dUdz = - (1-mu)/r1^3*z - mu/r2^3*z;

    % Assemble the state derivative in the documented component order.
    dxdt = zeros(6,1);

    dxdt(1:3) = xx(4:6);
    dxdt(4)   = dUdx + 2*vy;
    dxdt(5)   = dUdy - 2*vx;
    dxdt(6)   = dUdz;
    
end
