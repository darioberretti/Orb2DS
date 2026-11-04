function effective = resolve_accuracy(settings)
%RESOLVE_ACCURACY Resolve physical budgets and optional tighter exceptions.
%
% INPUT:
%   settings   options.accuracy; lengths km, velocities km/s, times days.
% OUTPUT:
%   effective  Per-requirement budgets. Empty or disabled exceptions inherit
%              global values. An enabled exception can only tighten them.

for name = {'position_km', 'velocity_km_s', 'time_days'}
    validateattributes(settings.(name{1}), {'double'}, ...
        {'scalar', 'real', 'finite', 'positive'});
end
validateattributes(settings.use_exceptions, {'logical'}, {'scalar'});
effective = settings;
groups = {'dynamics', 'departure', 'target', 'periapsis', 'clearance'};
for index = 1:numel(groups)
    group = groups{index};
    names = fieldnames(settings.(group));
    for item = 1:numel(names)
        name = names{item};
        if strcmp(name, 'altitude_km')
            general = settings.position_km;
        elseif strcmp(name, 'radial_velocity_km_s')
            general = settings.velocity_km_s;
        else
            general = settings.(name);
        end
        specific = settings.(group).(name);
        if ~isempty(specific)
            validateattributes(specific, {'double'}, {'scalar', 'real', 'finite', 'positive'});
        end
        effective.(group).(name) = general;
        if settings.use_exceptions && ~isempty(specific)
            effective.(group).(name) = min(general, specific);
        end
    end
end
end
