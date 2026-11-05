function effective = resolve_constraint_tolerances(options)
%RESOLVE_CONSTRAINT_TOLERANCES Inherit or tighten physical solver residual scales.
%
% PROTOTYPE:
%   effective = orb2ds.internal.resolve_constraint_tolerances(options)
%
% DESCRIPTION:
%   Validate physical thresholds and resolve optional solver residual scales.
%   Empty solver settings inherit validation; nonempty values can only tighten
%   their corresponding scale and never alter the independent validator.
%
% INPUT:
%   options  Merged numerical options. Validation tolerances and nonempty
%            solver constraint tolerances must be positive finite scalars.
%
% OUTPUT:
%   effective  Solver residual scales in km, km/s and days. Empty settings
%              inherit validation; supplied values apply min(validation,value).
%              Validation thresholds are never modified.

validation = options.validation;
names = fieldnames(validation);
for index = 1:numel(names)
    validateattributes(validation.(names{index}), {'double'}, ...
        {'scalar', 'real', 'finite', 'positive'});
end

effective = options.solver.constraint_tolerances;
effective.time_days = resolve(effective.time_days, validation.time_days);
groups = {'dynamics', 'departure', 'target', 'periapsis', 'clearance'};
for index = 1:numel(groups)
    group = groups{index};
    names = fieldnames(effective.(group));
    for item = 1:numel(names)
        name = names{item};
        if strcmp(name, 'altitude_km')
            general = validation.position_km;
        elseif strcmp(name, 'radial_velocity_km_s')
            general = validation.velocity_km_s;
        else
            general = validation.(name);
        end
        effective.(group).(name) = resolve(effective.(group).(name), general);
    end
end
end

function value = resolve(supplied, general)
%RESOLVE Apply a positive finite optional tolerance without relaxing validation.
value = general;
if ~isempty(supplied)
    validateattributes(supplied, {'double'}, {'scalar', 'real', 'finite', 'positive'});
    value = min(general, supplied);
end
end
