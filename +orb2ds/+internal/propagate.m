function [final_state, transition, times, states] = propagate(state, times, model, options)
%PROPAGATE Integrate normalized spatial CR3BP states, optionally with an STM.
%
% PROTOTYPE:
%   [xf, transition, times, states] = orb2ds.internal.propagate(x0, times, model, options)
%
% INPUT:
%   state    Six-component column in rotating DU/VU.
%   times    Requested normalized TU epochs; backward integration is valid.
%   model    Canonical model descriptor.
%   options  Resolved numerical options.
% OUTPUT:
%   final_state  Six-component final state in DU/VU.
%   transition   6x6 state transition matrix (only integrated if requested).
%   times/states Transient integration samples; never retained in results.
%                The STM maps normalized initial-state perturbations to the
%                final epoch; the augmented RHS uses column-major flattening.

use_stm = nargout >= 2;
if use_stm
    initial = [state(:); reshape(eye(6), 36, 1)];
    rhs = @(t, x) orb2ds.internal.rhs_CR3BP_3D_STM(t, x, model.mu);
else
    initial = state(:);
    rhs = @(t, x) orb2ds.internal.rhs_CR3BP_3D(t, x, model.mu);
end
if times(end) == times(1)
    final_state = state(:);
    transition = eye(6);
    times = times(:);
    states = repmat(state(:).', numel(times), 1);
    return
end
ode_options = odeset('RelTol', options.integration.relative_tolerance, ...
    'AbsTol', options.integration.absolute_tolerance);
requested_final = times(end);
[times, history] = ode113(rhs, times, initial, ode_options);
assert(times(end) == requested_final && all(isfinite(history(end, :))), ...
    'orb2ds:Integration', 'CR3BP integration did not reach its requested endpoint.');
final_state = history(end, 1:6).';
transition = [];
if use_stm
    transition = reshape(history(end, 7:42), 6, 6);
end
states = history(:, 1:6);
end
