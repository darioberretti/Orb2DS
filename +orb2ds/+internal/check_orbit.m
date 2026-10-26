function orbit = check_orbit(orbit)
%CHECK_ORBIT Validate the physical periodic-orbit descriptor without repair.

required = {'schema_version', 'state_ref', 'period_days', 'model'};
assert(isstruct(orbit) && isscalar(orbit) && all(isfield(orbit, required)), ...
    'orb2ds:Orbit', 'The orbit requires schema_version, state_ref, period_days and model.');
assert(isempty(setdiff(fieldnames(orbit), [required, {'provenance'}])), ...
    'orb2ds:UnknownField', 'Unknown orbit descriptor field.');
assert(orbit.schema_version == 1, 'orb2ds:Schema', 'Unsupported orbit schema.');
validateattributes(orbit.state_ref, {'double'}, {'real', 'finite', 'size', [6, 1]});
validateattributes(orbit.period_days, {'double'}, {'scalar', 'real', 'positive', 'finite'});

% Recompute derived quantities to reject inconsistent stored scales.
model = orbit.model;
primary_names = {'gm_earth_km3_s2', 'gm_moon_km3_s2', 'distance_km', ...
    'earth_radius_km', 'moon_radius_km', 'moon_angle_ref_rad'};
assert(all(isfield(model, primary_names)), 'orb2ds:Model', ...
    'The orbit model is missing primary physical parameters.');
primary = struct();
for index = 1:numel(primary_names)
    name = primary_names{index};
    primary.(name) = model.(name);
end
expected = orb2ds.earth_moon_model(primary);
assert(isempty(setxor(fieldnames(model), fieldnames(expected))) && ...
    strcmp(model.name, expected.name) && model.schema_version == 1, ...
    'orb2ds:Model', 'Use the complete earth_moon_model descriptor.');
derived = {'mu', 'time_days', 'velocity_km_s', 'encounter_radius_km'};
for index = 1:numel(derived)
    name = derived{index};
    assert(abs(model.(name) - expected.(name)) <= 1e-12 * abs(expected.(name)), ...
        'orb2ds:Model', 'Inconsistent derived model quantity: %s.', name);
end
end
