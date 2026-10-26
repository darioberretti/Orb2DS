function [variables, swapped] = regularize_impulses(impulses)
%REGULARIZE_IMPULSES Invert the thesis quadratic map without its logging/fallbacks.
%   Nx3 normalized impulses become Nx3 regularized variables. Preserve the
%   alternate chart for a purely negative x impulse and the epsilon zero seed.

variables = zeros(size(impulses));
swapped = false(size(impulses, 1), 1);
for index = 1:size(impulses, 1)
    vector = impulses(index, :).';
    magnitude = norm(vector);
    if magnitude < 1e-14
        variables(index, :) = eps;
        continue
    end
    if vector(1) < 0 && sum(vector(2:3).^2) < 1e-14
        vector = vector([2, 1, 3]);
        swapped(index) = true;
    end
    first = sqrt((magnitude + vector(1)) / 2);
    variables(index, :) = [first, vector(2) / (2 * first), vector(3) / (2 * first)];
end
end
