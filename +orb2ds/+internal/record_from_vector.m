function record = record_from_vector(vector, nlp)
%RECORD_FROM_VECTOR Decode a runtime NLP into the canonical compact physical data.

decoded = orb2ds.internal.decode_nlp(vector, nlp);
model = nlp.model;
scales = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
times = decoded.times * model.time_days;
events = nlp.seed.events;
events.moon_periapsis_days = times(nlp.moon_node);
events.earth_periapsis_days = times(end);
if isfield(events, 'moon_entry_node')
    events.moon_entry_days = times(events.moon_entry_node);
end
if isfield(events, 'moon_exit_node')
    events.moon_exit_days = times(events.moon_exit_node);
end
timing = struct('departure_phase', mod(decoded.phase, 1), ...
    'departure_time_days', times(1), 'final_time_days', times(end), ...
    'wait_days', [], 'transfer_days', times(end) - times(1), ...
    'total_days', times(end) - times(1));
if ~isempty(nlp.wait_index)
    timing.wait_days = decoded.wait * model.time_days;
    timing.total_days = timing.transfer_days + timing.wait_days;
    timing.initial_time_days = times(1) - timing.wait_days;
    timing.initial_phase = mod(decoded.phase - decoded.wait / nlp.period_tu, 1);
end
provenance = nlp.seed.provenance;
provenance.library_version = '0.1.0-dev';
record = struct('schema_version', 1, 'orbit', nlp.problem.orbit, ...
    'nodes', struct('time_days', times, 'state_post', decoded.states .* scales, ...
    'delta_v_km_s', decoded.impulses * model.velocity_km_s), ...
    'events', events, 'timing', timing, 'integration', nlp.options.integration, ...
    'provenance', provenance, ...
    'metrics', struct('delta_v_m_s', 1000 * sum(vecnorm(decoded.impulses, 2, 2)) ...
    * model.velocity_km_s));
record = orb2ds.internal.check_record(record);
end
