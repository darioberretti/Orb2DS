function record = check_record(record)
%CHECK_RECORD Validate the compact physical node representation, not feasibility.

required = {'schema_version', 'orbit', 'nodes', 'events', 'timing', ...
    'integration', 'provenance'};
assert(all(isfield(record, required)) && record.schema_version == 1, ...
    'orb2ds:Schema', 'Unsupported or incomplete compact physical record.');
assert(isempty(setdiff(fieldnames(record), [required, {'metrics'}])), ...
    'orb2ds:Schema', 'Unknown physical record field; migrate it explicitly.');
assert(isempty(setxor(fieldnames(record.nodes), ...
    {'time_days'; 'state_post'; 'delta_v_km_s'})), ...
    'orb2ds:Schema', 'Unknown node field; sampled trajectories are not node data.');
record.orbit = orb2ds.internal.check_orbit(record.orbit);
times = record.nodes.time_days;
states = record.nodes.state_post;
impulses = record.nodes.delta_v_km_s;
validateattributes(times, {'double'}, {'column', 'real', 'finite'});
count = numel(times);
assert(count >= 2 && all(diff(times) > 0), 'orb2ds:Nodes', ...
    'A transfer needs at least two strictly ordered nodes.');
validateattributes(states, {'double'}, {'size', [count, 6], 'real', 'finite'});
validateattributes(impulses, {'double'}, {'size', [count, 3], 'real', 'finite'});
validateattributes(record.timing.departure_phase, {'double'}, ...
    {'scalar', 'real', 'finite', '>=', 0, '<', 1});
end
