function [departure, arrival, success] = solve_lambert(r1, r2, days, gm)
%SOLVE_LAMBERT Use the pinned FEX zero-revolution historical retrograde branch.
%   Positions are km, duration days, GM km^3/s^2, output velocities km/s.
%   The branch/sign convention is extracted from rpo2ds.solve_lambert and
%   RPO2DS_solve_perp_lambert_tof. No global search-path change is made.

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
