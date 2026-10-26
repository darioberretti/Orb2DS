function same_orbit(reference, supplied)
%SAME_ORBIT Require identical conventions and numerically matching orbit data.

reference = orb2ds.internal.check_orbit(reference);
supplied = orb2ds.internal.check_orbit(supplied);
same_model = isequaln(reference.model, supplied.model);
same_state = max(abs(reference.state_ref - supplied.state_ref) ./ ...
    [repmat(reference.model.distance_km, 3, 1); ...
    repmat(reference.model.velocity_km_s, 3, 1)]) <= 1e-10;
same_period = abs(reference.period_days - supplied.period_days) <= ...
    1e-10 * reference.period_days;
assert(same_model && same_state && same_period, 'orb2ds:OrbitMismatch', ...
    'Orbit, model, reference phase or period differs from the supplied data.');
end
