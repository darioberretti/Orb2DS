function [Rp, Vp, rhat_p, that_p, hhat] = rp_circle_from_vinfplus(vinf_plus, rp, mu, N, az0)
%RP_CIRCLE_FROM_VINFPLUS Sample periapsis directions for fixed vInf+ and rp.
%
% PURPOSE
%   For a given outgoing asymptote vInf+ (vector), scalar periapsis radius rp,
%   and mu, generate N evenly spaced periapsis direction vectors rhat_p lying on
%   the small circle defined by angle(rhat_p, s_plus) = nu_inf, and return the
%   corresponding periapsis velocity vectors Vp (purely tangential).
%
% USAGE
%   [Rp, Vp] = rp_circle_from_vinfplus(vinf_plus, rp, mu, N)
%   [Rp, Vp, rhat_p, that_p, hhat] = ... (returns unit vectors too)
%   [Rp, Vp] = rp_circle_from_vinfplus(vinf_plus, rp, mu, N, az0)
%
% INPUTS
%   vinf_plus : 1x3 or 3x1 outgoing hyperbolic excess velocity vector
%   rp        : scalar periapsis radius (same for all samples)
%   mu        : scalar gravitational parameter
%   N         : scalar number of evenly spaced samples along the circle
%   az0       : optional B-plane azimuth offset in radians (default 0)
%
% OUTPUTS
%   Rp      : Nx3 periapsis position vectors (ECI), each row has ||Rp(i,:)|| = rp
%   Vp      : Nx3 periapsis velocity vectors (ECI) for the outgoing branch
%   rhat_p  : Nx3 unit periapsis directions
%   that_p  : Nx3 unit tangent directions at periapsis (direction of Vp)
%   hhat    : Nx3 unit orbit-plane normals
%

if nargin < 5
    az0 = 0;
end

% Normalize asymptote direction and get magnitude
s = vinf_plus(:).';
vinf = norm(s);
if ~isfinite(vinf) || vinf == 0
    error('vinf_plus must be a non-zero 3-vector.');
end
s = s / vinf;

% Hyperbola parameters and periapsis speed
% e = 1 + rp * vinf^2 / mu
% nu_inf = acos(-1/e)
% vp at periapsis from vis-viva

e = 1 + rp * (vinf^2) / mu;
if e <= 1
    error('Computed eccentricity e <= 1. Check rp, vinf, mu.');
end
nu = acos(-1/e);
a = -mu / (vinf^2);
vp = sqrt(mu * ((1 + e) / a / (1 - e)));

% Orthonormal basis of B-plane (perpendicular to s)
ref = [1 0 0];
if abs(dot(s, ref)) > 0.99
    ref = [0 1 0];
end

% e1,e2 are unit vectors spanning the B-plane

e1 = cross(s, ref);  e1 = e1 / norm(e1);
e2 = cross(s, e1);

% Evenly spaced azimuths around the circle
zeta = az0 + (0:N-1).' * (2*pi/N);

% B-plane unit directions
Bhat = cos(zeta).*e1 + sin(zeta).*e2;

% Orbit-plane normals
hhat = normalize_rows(cross_rows(repmat(s, N, 1), Bhat));

% Periapsis tangent directions
that_p = normalize_rows(cos(nu).*Bhat - sin(nu).*repmat(s, N, 1));

% Periapsis direction
rhat_p = normalize_rows(cross_rows(hhat, that_p));

% Scale to rp and vp
Rp = -rp * rhat_p;
Vp = -vp * that_p;

end
function Vn = normalize_rows(V)
%NORMALIZE_ROWS Normalize each vector row with the implemented zero-norm guard.

    n = vecnorm(V, 2, 2);
    Vn = V ./ n;
end

function C = cross_rows(A, B)
%CROSS_ROWS Evaluate row-wise cross products for the sampled perigee basis.

    C = [A(:,2).*B(:,3)-A(:,3).*B(:,2), ...
         A(:,3).*B(:,1)-A(:,1).*B(:,3), ...
         A(:,1).*B(:,2)-A(:,2).*B(:,1)];
end

