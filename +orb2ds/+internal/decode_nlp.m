function decoded = decode_nlp(vector, nlp)
%DECODE_NLP Decode physical meanings of the internal normalized variables.

count = nlp.n_nodes;
blocks = reshape(vector(1:9 * count), 9, count).';
decoded.states = blocks(:, 1:6);
decoded.regularized = blocks(:, 7:9);
decoded.impulses = zeros(count, 3);
for index = 1:count
    decoded.impulses(index, :) = orb2ds.internal.impulse_map( ...
        decoded.regularized(index, :), nlp.swapped(index)).';
end
decoded.durations = vector(nlp.duration_indices);
decoded.wait = 0;
if ~isempty(nlp.wait_index)
    decoded.wait = vector(nlp.wait_index);
end
constraints = nlp.problem.constraints;
if isempty(nlp.epoch_index)
    decoded.departure_epoch = constraints.initial_time_days / nlp.model.time_days + decoded.wait;
else
    decoded.departure_epoch = vector(nlp.epoch_index);
end
if isempty(nlp.phase_index)
    decoded.phase = constraints.initial_phase + decoded.wait / nlp.period_tu;
else
    decoded.phase = vector(nlp.phase_index);
end
decoded.times = decoded.departure_epoch + [0; cumsum(decoded.durations)];
end
