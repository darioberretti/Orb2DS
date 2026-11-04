classdef ShootingJacobian < casadi.Callback
    %SHOOTINGJACOBIAN Supply a fixed structural sparsity, including seed zeros.
    properties
        owner
        pattern
        entries
    end
    methods
        function self = ShootingJacobian(name, owner)
            self@casadi.Callback();
            self.owner = owner;
            self.pattern = casadi.DM(owner.pattern).sparsity();
            self.entries = find(owner.pattern);
            construct(self, name);
        end
        function count = get_n_in(~)
            count = 2;
        end
        function count = get_n_out(~)
            count = 1;
        end
        function pattern = get_sparsity_in(self, index)
            if index == 0
                pattern = casadi.Sparsity.dense(self.owner.nlp.n_variables, 1);
            else
                pattern = casadi.Sparsity.dense(size(self.owner.pattern, 1), 1);
            end
        end
        function pattern = get_sparsity_out(self, ~)
            pattern = self.pattern;
        end
        function output = eval(self, input)
            self.owner.evaluate(full(input{1}));
            values = full(self.owner.last_jacobian(self.entries));
            output = {casadi.DM(self.pattern, values)};
        end
    end
end
