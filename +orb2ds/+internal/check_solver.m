function check_solver(options)
%CHECK_SOLVER Fail before leg searches when an optional dependency is absent.
if strcmp(options.solver.name, 'fmincon')
    assert(exist('fmincon', 'file') == 2, 'orb2ds:MissingSolver', ...
        'fmincon requires MATLAB Optimization Toolbox.');
else
    assert(~isempty(which('casadi.nlpsol')), 'orb2ds:MissingSolver', ...
        'Add the installed CasADi MATLAB directory to the path before selecting IPOPT.');
    assert(casadi.has_nlpsol('ipopt'), 'orb2ds:MissingSolver', ...
        'The installed CasADi build must include the IPOPT plugin.');
end
end
