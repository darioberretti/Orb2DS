function effective = merge_options(defaults, supplied, location)
%MERGE_OPTIONS Merge known leaves recursively without treating zero as absent.
%   Unknown fields and malformed blocks are input errors. Empty numerical
%   leaves are rejected: remove a field to request its documented default.

assert(isstruct(supplied) && isscalar(supplied), 'orb2ds:Options', ...
    '%s must be a scalar structure.', location);
effective = defaults;
names = fieldnames(supplied);
for index = 1:numel(names)
    name = names{index};
    assert(isfield(defaults, name), 'orb2ds:UnknownField', ...
        'Unknown setting: %s.%s.', location, name);
    value = supplied.(name);
    if isstruct(defaults.(name))
        effective.(name) = orb2ds.internal.merge_options( ...
            defaults.(name), value, [location '.' name]);
    else
        assert(~isempty(value), 'orb2ds:Options', ...
            'Empty numerical setting: %s.%s; omit it to use the default.', location, name);
        effective.(name) = value;
    end
end
end
