classdef ShootingCallback < casadi.Callback
    %SHOOTINGCALLBACK Expose MATLAB residuals and STM derivatives to CasADi.
    %   Keep this owner alive throughout the solve. A cached full evaluation
    %   avoids propagating twice when IPOPT asks for a value and its Jacobian.
    properties
        nlp
        pattern
        jacobian_callback
        last_vector = []
        last_value
        last_jacobian
    end
    methods
        function self = ShootingCallback(name, nlp)
            self@casadi.Callback();
            self.nlp = nlp;
            self.pattern = structural_pattern(nlp);
            construct(self, name);
        end
        function count = get_n_in(~)
            count = 1;
        end
        function count = get_n_out(~)
            count = 1;
        end
        function pattern = get_sparsity_in(self, ~)
            pattern = casadi.Sparsity.dense(self.nlp.n_variables, 1);
        end
        function pattern = get_sparsity_out(self, ~)
            pattern = casadi.Sparsity.dense(size(self.pattern, 1), 1);
        end
        function output = eval(self, input)
            self.evaluate(full(input{1}));
            output = {self.last_value};
        end
        function available = has_jacobian(~)
            available = true;
        end
        function available = has_jac_sparsity(~, varargin)
            available = true;
        end
        function pattern = get_jac_sparsity(self, varargin)
            pattern = casadi.DM(self.pattern).sparsity();
        end
        function callback = get_jacobian(self, name, varargin)
            self.jacobian_callback = orb2ds.internal.ShootingJacobian(name, self);
            callback = self.jacobian_callback;
        end
        function evaluate(self, vector)
            if isequal(vector, self.last_vector)
                return
            end
            previous = warning('off', 'MATLAB:ode113:IntegrationTolNotMet');
            restore_warning = onCleanup(@() warning(previous));
            try
                [c, ceq, gc, geq] = orb2ds.internal.constraints(vector, self.nlp);
                self.last_value = [ceq; c];
                self.last_jacobian = [geq.'; gc.'];
            catch exception
                if ~strcmp(exception.identifier, 'orb2ds:Integration')
                    rethrow(exception)
                end
                % A failed trial flow is recoverable by IPOPT's line search.
                self.last_value = nan(size(self.pattern, 1), 1);
                self.last_jacobian = spfun(@(x) nan(size(x)), self.pattern);
            end
            self.last_vector = vector;
        end
    end
end

function pattern = structural_pattern(nlp)
%STRUCTURAL_PATTERN Include possible nonzeros even when the seed is planar.
count = nlp.n_nodes;
neq = 6 * count + 5;
pattern = sparse(neq + 2 * count + 3, nlp.n_variables);
pattern(1:6, 1:9) = 1;
pattern(1:6, [nlp.phase_index, nlp.wait_index(isempty(nlp.phase_index))]) = 1;
for index = 1:count - 1
    rows = 6 * index + (1:6);
    pattern(rows, 9 * (index - 1) + (1:6)) = 1;
    pattern(rows, 9 * index + (1:9)) = 1;
    pattern(rows, nlp.duration_indices(index)) = 1;
end
pattern(6 * count + 1, 9 * (nlp.moon_node - 1) + (1:6)) = 1;
pattern(6 * count + (2:5), 9 * (count - 1) + (1:6)) = 1;
pattern(6 * count + (2:5), [nlp.duration_indices, nlp.epoch_index, ...
    nlp.wait_index(isempty(nlp.epoch_index))]) = 1;
for index = 1:count
    pattern(neq + [index, count + index], 9 * (index - 1) + (1:3)) = 1;
end
pattern(neq + 2 * count + 1, 9 * (nlp.moon_node - 1) + (1:6)) = 1;
pattern(neq + 2 * count + 2, 9 * (count - 1) + (1:6)) = 1;
pattern(neq + 2 * count + 3, 9 * (count - 1) + (1:6)) = 1;
pattern(neq + 2 * count + 3, [nlp.duration_indices, nlp.epoch_index, ...
    nlp.wait_index(isempty(nlp.epoch_index))]) = 1;
end
