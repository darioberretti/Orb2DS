function states = evaluate_arc(arc, epochs, model, options)
%EVALUATE_ARC Sample a compact physical recipe on either side of its anchor.
%
% PROTOTYPE:
%   states = orb2ds.internal.evaluate_arc(arc, epochs, model, options)
% INPUT:
%   arc      Assembled CR3BP or Earth-two-body initial-value recipe.
%   epochs   Nx1 local query epochs [days], inside this arc's interval.
%   model    Canonical model descriptor.
%   options  Resolved integration settings.
% OUTPUT:
%   Output is Nx6 barycentric rotating km/km/s at local epochs in days.
%   Temporary integration samples are returned only to assembly/meshing.

epochs = epochs(:);
assert(all(epochs >= arc.start_days - 1e-10 & epochs <= arc.end_days + 1e-10), ...
    'orb2ds:Arc', 'Requested samples lie outside this physical arc.');
if strcmp(arc.kind, 'cr3bp')
    scale = [repmat(model.distance_km, 1, 3), repmat(model.velocity_km_s, 1, 3)];
    time_scale = model.time_days;
    rhs = @(t, x) orb2ds.internal.rhs_CR3BP_3D(t, x, model.mu);
else
    assert(strcmp(arc.kind, 'earth_two_body'), 'orb2ds:Arc', 'Unknown physical arc model.');
    scale = ones(1, 6);
    time_scale = 1 / 86400;
    rhs = @(~, x) [x(4:6); -model.gm_earth_km3_s2 * x(1:3) / sum(x(1:3).^2)^(3 / 2)];
end
initial = arc.initial_state(:) ./ scale.';
states = repmat(arc.initial_state(:).', numel(epochs), 1);
ode_options = odeset('RelTol', options.integration.relative_tolerance, ...
    'AbsTol', options.integration.absolute_tolerance);
for direction = [-1, 1]
    selected = find((epochs - arc.initial_days) * direction > 0);
    [~, order] = sort(direction * epochs(selected));
    selected = selected(order);
    if isempty(selected)
        continue
    end
    requested = [arc.initial_days; epochs(selected)] / time_scale;
    [times, history] = ode113(rhs, requested, initial, ode_options);
    assert(times(end) == requested(end), 'orb2ds:Integration', ...
        'Arc integration did not reach the requested endpoint.');
    if numel(requested) == 2
        states(selected, :) = history(end, :) .* scale;
    else
        states(selected, :) = history(2:end, :) .* scale;
    end
end
if strcmp(arc.kind, 'earth_two_body')
    states = orb2ds.internal.frames(states, epochs, model, 'to_rotating');
end
end
