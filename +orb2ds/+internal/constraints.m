function [inequality, equality, gradient_inequality, gradient_equality] = constraints(vector, nlp)
%CONSTRAINTS Multiple-shooting defects, orbit boundary and Earth/Moon events.
%
% PROTOTYPE:
%   [c, ceq, gc, gceq] = orb2ds.internal.constraints(vector, nlp)
%
% DESCRIPTION:
%   Segment sensitivities use the reused analytic CR3BP STM. Small local
%   event derivatives use complex-step differentiation of analytic formulas.
%   Output Jacobians follow fmincon's variables-by-constraints convention.
%
% INPUT:
%   vector  Packed normalized node/impulse/timing variables from build_nlp.
%   nlp     Runtime layout and current physical problem.
% OUTPUT:
%   inequality/equality           Column residuals in normalized quantities.
%   gradient_inequality/equality  Sparse variable-by-residual Jacobians.
%   Inequalities are feasible at <=0 and equalities at zero. Physical
%   acceptance is measured separately by validate_solution in declared units.

decoded = orb2ds.internal.decode_nlp(vector, nlp);
count = nlp.n_nodes;
model = nlp.model;
with_gradient = nargout > 2;
equality = zeros(6 * count + 5, 1);
inequality = zeros(2 * count + 2, 1);
J = sparse(numel(equality), nlp.n_variables);
G = sparse(numel(inequality), nlp.n_variables);

% Departure post-impulse state must belong to the prescribed periodic orbit.
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
phase_time = mod(decoded.phase, 1) * nlp.period_tu;
orbit_state = orb2ds.internal.propagate(nlp.problem.orbit.state_ref ./ scale, ...
    [0, phase_time], model, nlp.options);
[burn, burn_jacobian] = orb2ds.internal.impulse_map(decoded.regularized(1, :), nlp.swapped(1));
equality(1:6) = decoded.states(1, :).' - orbit_state - [zeros(3, 1); burn];
if with_gradient
    J(1:6, 1:6) = eye(6);
    J(4:6, 7:9) = -burn_jacobian;
    rate = orb2ds.internal.rhs_CR3BP_3D(0, orbit_state, model.mu);
    if ~isempty(nlp.phase_index)
        J(1:6, nlp.phase_index) = -rate * nlp.period_tu;
    else
        J(1:6, nlp.wait_index) = -rate;
    end
end

% Each arc ends before the receiving node's impulse.
for index = 1:count - 1
    state = decoded.states(index, :).';
    duration = decoded.durations(index);
    if with_gradient
        [arrival, transition] = orb2ds.internal.propagate(state, [0, duration], model, nlp.options);
    else
        arrival = orb2ds.internal.propagate(state, [0, duration], model, nlp.options);
    end
    [burn, burn_jacobian] = orb2ds.internal.impulse_map( ...
        decoded.regularized(index + 1, :), nlp.swapped(index + 1));
    rows = 6 * index + (1:6);
    equality(rows) = arrival - decoded.states(index + 1, :).' + [zeros(3, 1); burn];
    if with_gradient
        J(rows, 9 * (index - 1) + (1:6)) = transition;
        J(rows, 9 * index + (1:6)) = -eye(6);
        J(rows(4:6), 9 * index + (7:9)) = burn_jacobian;
        J(rows, nlp.duration_indices(index)) = ...
            orb2ds.internal.rhs_CR3BP_3D(0, arrival, model.mu);
    end
end

% Body clearance is enforced at nodes and checked again on full arcs later.
earth_position = decoded.states(:, 1:3) + [model.mu, 0, 0];
moon_position = decoded.states(:, 1:3) - [1 - model.mu, 0, 0];
inequality(1:count) = nlp.min_earth^2 - sum(earth_position.^2, 2);
inequality(count + (1:count)) = nlp.min_moon^2 - sum(moon_position.^2, 2);
for index = 1:count
    columns = 9 * (index - 1) + (1:3);
    G(index, columns) = -2 * earth_position(index, :);
    G(count + index, columns) = -2 * moon_position(index, :);
end

% Retain the thesis lunar/Earth periapsis conditions.
moon_state = decoded.states(nlp.moon_node, :).';
[moon_speed, moon_acceleration] = orb2ds.internal.radial_event( ...
    moon_state, [1 - model.mu; 0; 0], model.mu);
[~, earth_acceleration] = orb2ds.internal.radial_event( ...
    decoded.states(end, :).', [-model.mu; 0; 0], model.mu);
equality(6 * count + 1) = moon_speed;
equality(6 * count + (2:5)) = orb2ds.internal.terminal_boundary( ...
    decoded.states(end, :).', decoded.times(end), nlp);
inequality(2 * count + (1:2)) = -[moon_acceleration; earth_acceleration];
if with_gradient
    step = 1e-20;
    for component = 1:6
        perturbation = zeros(6, 1);
        perturbation(component) = 1i * step;
        [speed, acceleration] = orb2ds.internal.radial_event( ...
            moon_state + perturbation, [1 - model.mu; 0; 0], model.mu);
        column = 9 * (nlp.moon_node - 1) + component;
        J(6 * count + 1, column) = imag(speed) / step;
        G(2 * count + 1, column) = -imag(acceleration) / step;
        endpoint = decoded.states(end, :).' + perturbation;
        boundary = orb2ds.internal.terminal_boundary(endpoint, decoded.times(end), nlp);
        J(6 * count + (2:5), 9 * (count - 1) + component) = imag(boundary) / step;
        [~, acceleration] = orb2ds.internal.radial_event(endpoint, [-model.mu; 0; 0], model.mu);
        G(2 * count + 2, 9 * (count - 1) + component) = -imag(acceleration) / step;
    end
    boundary = orb2ds.internal.terminal_boundary(decoded.states(end, :).', ...
        decoded.times(end) + 1i * step, nlp);
    time_derivative = imag(boundary) / step;
    time_columns = [nlp.duration_indices, nlp.epoch_index, nlp.wait_index(isempty(nlp.epoch_index))];
    J(6 * count + (2:5), time_columns) = repmat(time_derivative, 1, numel(time_columns));
end
gradient_equality = J.';
gradient_inequality = G.';
end
