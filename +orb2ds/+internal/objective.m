function [cost, gradient] = objective(vector, nlp)
%OBJECTIVE Sum normalized impulse magnitudes using the thesis quadratic map.

indices = reshape((1:9 * nlp.n_nodes), 9, nlp.n_nodes);
indices = indices(7:9, nlp.active_impulses);
indices = indices(:);
cost = sum(vector(indices).^2);
gradient = zeros(size(vector));
gradient(indices) = 2 * vector(indices);
end
