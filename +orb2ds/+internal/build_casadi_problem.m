function graph = build_casadi_problem(nlp)
%BUILD_CASADI_PROBLEM Build an IPOPT graph with MATLAB or symbolic evaluation.
%
% PROTOTYPE:
%   graph = orb2ds.internal.build_casadi_problem(nlp)
% DESCRIPTION:
%   Preserve build_nlp's variable layout, normalization and constraint order.
%   The MATLAB route supplies the existing STM Jacobians through callbacks.
%   The symbolic route uses a CVODES flow on normalized time [0,1],
%   sharing impulse, frame, target and periapsis algebra with MATLAB.
% INPUT:
%   nlp    Runtime shooting problem; solver.evaluation selects the route.
% OUTPUT:
%   graph  CasADi NLP, constraint bounds, evaluators and callback owners.
%          Runtime only: never save this structure inside transfer results.

import casadi.*
timer = tic;
vector = MX.sym('x', nlp.n_variables);
indices = reshape(1:9 * nlp.n_nodes, 9, nlp.n_nodes);
indices = indices(7:9, nlp.active_impulses);
cost = sumsqr(vector(indices(:)));
graph.callbacks = {};
graph.integrator_options = struct();
if strcmp(nlp.options.solver.evaluation, 'matlab')
    callback = orb2ds.internal.ShootingCallback('shooting', nlp);
    residual = callback(vector);
    graph.callbacks = {callback};
else
    [residual, graph.integrator_options] = symbolic_constraints(vector, nlp);
end
equalities = 6 * nlp.n_nodes + 5;
inequalities = 2 * nlp.n_nodes + 3;
all_constraints = [residual; nlp.A * vector - nlp.b];
graph.nlp = struct('x', vector, 'f', cost, 'g', all_constraints);
graph.lower = [zeros(equalities, 1); -inf(inequalities + numel(nlp.b), 1)];
graph.upper = zeros(numel(graph.lower), 1);
graph.constraints = Function('constraints', {vector}, {all_constraints});
graph.jacobian = Function('jacobian', {vector}, {jacobian(all_constraints, vector)});
graph.objective = Function('objective', {vector}, {cost, gradient(cost, vector)});
graph.build_seconds = toc(timer);
end

function [residual, settings] = symbolic_constraints(vector, nlp)
%SYMBOLIC_CONSTRAINTS Build symbolic shooting, boundary and clearance residuals.
import casadi.*
model = nlp.model;
count = nlp.n_nodes;
settings = struct('reltol', nlp.options.integration.relative_tolerance, ...
    'abstol', nlp.options.integration.absolute_tolerance, 'max_num_steps', 100000, ...
    'ad_weight', 0, 'enable_reverse', false);
names = fieldnames(nlp.options.solver.cvodes);
for index = 1:numel(names)
    settings.(names{index}) = nlp.options.solver.cvodes.(names{index});
end
state = MX.sym('state', 6);
duration = MX.sym('duration');
flow = integrator('cr3bp_flow', 'cvodes', ...
    struct('x', state, 'p', duration, 'ode', duration * symbolic_rhs(state, model.mu)), ...
    0, 1, settings);

blocks = reshape(vector(1:9 * count), 9, count);
states = blocks(1:6, :);
burns = cell(count, 1);
for index = 1:count
    burns{index} = orb2ds.internal.impulse_map(blocks(7:9, index), nlp.swapped(index));
end
durations = vector(nlp.duration_indices);
wait = 0;
if ~isempty(nlp.wait_index)
    wait = vector(nlp.wait_index);
end
if isempty(nlp.epoch_index)
    epoch = nlp.problem.constraints.initial_time_days / model.time_days + wait;
else
    epoch = vector(nlp.epoch_index);
end
if isempty(nlp.phase_index)
    phase = nlp.problem.constraints.initial_phase + wait / nlp.period_tu;
else
    phase = vector(nlp.phase_index);
end
% floor implements MATLAB mod for a positive divisor, including phase=1.
phase = phase - floor(phase);
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
departure = flow('x0', nlp.problem.orbit.state_ref ./ scale, 'p', phase * nlp.period_tu);
equalities = cell(count + 2, 1);
equalities{1} = states(:, 1) - departure.xf - [zeros(3, 1); burns{1}];
for index = 1:count - 1
    arrival = flow('x0', states(:, index), 'p', durations(index));
    equalities{index + 1} = arrival.xf - states(:, index + 1) + ...
        [zeros(3, 1); burns{index + 1}];
end
moon = states(:, nlp.moon_node);
[moon_speed, moon_acceleration] = orb2ds.internal.radial_event( ...
    moon, [1 - model.mu; 0; 0], model.mu, symbolic_rhs(moon, model.mu));
last = states(:, end);
last_rate = symbolic_rhs(last, model.mu);
[~, earth_acceleration] = orb2ds.internal.radial_event( ...
    last, [-model.mu; 0; 0], model.mu, last_rate);
equalities{count + 1} = moon_speed;
[equalities{count + 2}, energy_guard] = orb2ds.internal.terminal_boundary( ...
    last, epoch + sum1(durations), nlp, last_rate);
earth = states(1:3, :) + repmat([model.mu; 0; 0], 1, count);
moon = states(1:3, :) - repmat([1 - model.mu; 0; 0], 1, count);
residual = [vertcat(equalities{:}); ...
    (nlp.min_earth - sqrt(sum1(earth.^2))).'; ...
    (nlp.min_moon - sqrt(sum1(moon.^2))).'; -moon_acceleration; -earth_acceleration; energy_guard];
residual = [nlp.equality_scale; nlp.inequality_scale] .* residual;
end

function rate = symbolic_rhs(state, mu)
%SYMBOLIC_RHS Evaluate spatial CR3BP dynamics with symbolic state components.
position = state(1:3);
velocity = state(4:6);
earth = position + [mu; 0; 0];
moon = position - [1 - mu; 0; 0];
acceleration = [position(1) + 2 * velocity(2); ...
    position(2) - 2 * velocity(1); 0] - ...
    (1 - mu) * earth / sqrt(sum(earth.^2))^3 - mu * moon / sqrt(sum(moon.^2))^3;
rate = [velocity; acceleration];
end
