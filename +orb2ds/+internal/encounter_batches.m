function [earth_batch, first, last] = encounter_batches(problem, departures, orbit_days, moon_angles)
%ENCOUNTER_BATCHES Assign lunar encounter geometry before comparing velocities.
%
%   Earth legs supply Moon angles [rad]. Each orbit leg supplies an elapsed
%   time to the SOI [days] and its fixed waiting replica, if any. Return the
%   Earth-leg bins and each orbit leg's inclusive range of reachable bins.
%   A final bin above the number of samples denotes a wrap around the circle.

constraints = problem.constraints;
earth_batch = ones(numel(moon_angles), 1);
first = ones(size(orbit_days));
last = first;
if ~isfield(constraints, 'initial_time_days')
    return
end

model = problem.orbit.model;
epoch = constraints.initial_time_days + departures.wait_days + orbit_days;
angle = model.moon_angle_ref_rad + epoch / model.time_days;
sweep = 0;
if ~isfield(constraints, 'initial_phase')
    sweep = constraints.max_wait_time_days / model.time_days;
end
if strcmp(problem.target.frame, 'eci')
    cycle = 2 * pi;
    [samples, ~, earth_batch] = unique(mod(moon_angles(:), cycle));
    if sweep >= cycle
        last(:) = numel(samples);
        return
    end
    seam = (samples(end) + samples(1) - cycle) / 2;
    edges = [seam; (samples(1:end-1) + samples(2:end)) / 2; seam + cycle];
    offset = mod(angle - seam, cycle);
    first = discretize(seam + offset, edges, 'IncludedEdge', 'right');
    last = discretize(seam + mod(offset + sweep, cycle), edges, 'IncludedEdge', 'right');
    last = last + numel(samples) * (offset + sweep >= cycle);
else
    % The Sun-relative target depends on the absolute epoch of the Earth leg.
    [samples, ~, earth_batch] = unique(moon_angles(:));
    edges = [-Inf; (samples(1:end-1) + samples(2:end)) / 2; Inf];
    first = discretize(angle, edges, 'IncludedEdge', 'right');
    last = discretize(angle + sweep, edges, 'IncludedEdge', 'right');
end
end
