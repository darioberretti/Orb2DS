function [velocity, derivative] = target_eci(target, time_days)
%TARGET_ECI Evaluate the prescribed outgoing excess velocity and time derivative.
%   Velocity is km/s and its derivative km/s per day. The RTH geometry angle
%   points Earth-to-Sun; radial points Sun-to-Earth, matching the thesis axes.

velocity = target.vinf_km_s(:);
derivative = zeros(3, 1);
if strcmp(target.frame, 'earth_sun_rth')
    geometry = target.solar_geometry;
    angle = geometry.angle_ref_rad + geometry.rate_rad_day * time_days;
    c = cos(angle);
    s = sin(angle);
    matrix = [-c, s, 0; -s, -c, 0; 0, 0, 1];
    change = [s, c, 0; -c, s, 0; 0, 0, 0];
    derivative = geometry.rate_rad_day * change * velocity;
    velocity = matrix * velocity;
end
end
