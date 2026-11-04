function [departure, arrival, success] = solve_lambert(r1, r2, days, gm)
%SOLVE_LAMBERT Evaluate the bundled FEX zero-revolution retrograde branch.
%   Positions are km, duration days, GM km^3/s^2, output velocities km/s.
%   The signed duration selects the retrograde branch using the z component
%   of cross(r1,r2). The reference direction is the positive inertial z axis.

normal = cross(r1(:), r2(:));
orientation = sign(normal(3));
if orientation == 0
    orientation = 1;
end
[departure, arrival, ~, flag] = orb2ds.thirdparty.fexlambert.lambert( ...
    r1(:).', r2(:).', -orientation * days, 0, gm);
departure = departure(:);
arrival = arrival(:);
success = flag == 1 && all(isfinite([departure; arrival]));
end
