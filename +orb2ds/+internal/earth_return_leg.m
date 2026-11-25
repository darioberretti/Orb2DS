function leg = earth_return_leg(problem, exit_state, exit_days, radius, sample, ...
    target_days, try_nearby, options)
%EARTH_RETURN_LEG Fit a tangent Earth return from the finite lunar exit.
%
%   exit_state is the rotating state [km, km/s] at exit_days [local days].
%   Sample the perigee circle of radius [km] for the target at target_days
%   [local days].
%   Try the selected sample only, or its nearest neighbors in order.
%   Return an inertial two-body arc, perigee impulse [km/s], target epoch
%   error [km/s] and selected sample, or [] if the fit fails.

model = problem.orbit.model;
exit_eci = orb2ds.internal.frames(exit_state(:).', exit_days, model, 'to_eci');
target = orb2ds.internal.target_eci(problem.target, target_days);
[positions, velocities] = orb2ds.internal.rp_circle_from_vinfplus( ...
    target, radius, model.gm_earth_km3_s2, options.patching.n_perigee);
samples = sample;
if try_nearby
    [~, order] = sort(vecnorm(positions - positions(sample, :), 2, 2));
    samples = order.';
end

leg = [];
for sample = samples
    [duration, first, last, success] = orb2ds.internal.perigee_lambert( ...
        exit_eci(1:3).', positions(sample, :).', model, options);
    if success
        arrival = exit_days + duration;
        arc = struct('kind', 'earth_two_body', 'start_days', exit_days, ...
            'end_days', arrival, 'initial_days', exit_days, 'initial_state', [exit_eci(1:3).'; first]);
        leg = struct('arc', arc, 'delta_v_eci_km_s', velocities(sample, :).' - last, ...
            'target_epoch_error_km_s', norm(target - orb2ds.internal.target_eci(problem.target, arrival)), ...
            'perigee_sample', sample);
        return
    end
end
end
