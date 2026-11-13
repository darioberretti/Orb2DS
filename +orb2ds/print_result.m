function print_result(result, show_validation)
%PRINT_RESULT Display physical checks and the returned transfer's status.
%
% PROTOTYPE:
%   orb2ds.print_result(result)
%   orb2ds.print_result(result, show_validation)
%
% DESCRIPTION:
%   Display stored validation diagnostics without running a solver or a new
%   propagation. Show values and limits for local and continuous residuals.
%   Automatic exploratory reports show only the transfer summary. This explicit
%   call prints regardless of output.display.
%
% INPUT:
%   result  Orb2DS result, in memory or loaded from a saved MAT file.
%   show_validation  Optional logical scalar. True (default) includes the
%                  physical validation and continuous propagation blocks.
% OUTPUT:
%   None. The input is unchanged and no files or trajectory samples are created.

if nargin < 2
    show_validation = true;
end
validateattributes(result, {'struct'}, {'scalar'});
validateattributes(show_validation, {'logical'}, {'scalar'});
policy = result.inputs.options.validation;
require_pass = ~isfield(policy, 'require_pass') || policy.require_pass;
if show_validation && isfield(result.validation, 'checks')
    v = result.validation;
    t = v.tolerances;
    fprintf('\n[Orb2DS] Physical validation\n\n');
    fprintf('  Multiple-shooting checks       : %s\n\n', verdict(v.local_is_feasible));
    fprintf('  %-30s %12s %12s    %s\n', 'Local residual', 'Value', 'Limit', 'Result');
    residuals({'Segment position [m]', 'Segment velocity [mm/s]', ...
        'Departure position [m]', 'Departure velocity [mm/s]', 'Target velocity [mm/s]'}, ...
        [v.max_position_defect_km, v.max_velocity_defect_km_s, v.departure_position_error_km, ...
        v.departure_velocity_error_km_s, v.target_error_km_s], ...
        [t.position_km, t.velocity_km_s, t.position_km, t.velocity_km_s, t.velocity_km_s], ...
        [1000, 1e6, 1000, 1e6, 1e6]);
    fprintf('\n');
    names = {'segment_endpoints_reached', 'orbit_closure', 'periapses', 'clearance', ...
        'impulse_policy', 'timing'};
    labels = {'Integration endpoints', 'Orbit closure', 'Periapsis conditions', ...
        'Body clearance', 'Impulse policy', 'Timing constraints'};
    for index = 1:numel(names)
        fprintf('  %-30s : %s\n', labels{index}, verdict(v.checks.(names{index})));
    end

    c = v.chained;
    fprintf('\n[Orb2DS] Continuous propagation\n\n');
    fprintf('  Reached final epoch            : %s\n', verdict(c.reached_final_epoch));
    fprintf('  Endpoint closure               : %s\n', verdict(c.closes_within_tolerances));
    fprintf('  Physical acceptance            : %s\n\n', verdict(c.is_feasible));
    fprintf('  %-30s %12s %12s    %s\n', 'Continuous residual', 'Value', 'Limit', 'Result');
    residuals({'Endpoint position [m]', 'Endpoint velocity [mm/s]', ...
        'Target velocity [mm/s]'}, [c.endpoint_position_error_km, ...
        c.endpoint_velocity_error_km_s, c.target_error_km_s], ...
        [t.position_km, t.velocity_km_s, t.velocity_km_s], [1000, 1e6, 1e6]);

    constraints = result.inputs.problem.constraints;
    minimum = [0, 0];
    if isfield(constraints, 'min_earth_altitude_km')
        minimum(1) = constraints.min_earth_altitude_km;
    end
    if isfield(constraints, 'min_moon_altitude_km')
        minimum(2) = constraints.min_moon_altitude_km;
    end
    continuous_clearance = [c.min_earth_altitude_km, c.min_moon_altitude_km] >= minimum - t.position_km;
    fprintf('\n  %-18s %14s %14s %12s    %s\n', ...
        'Altitude [km]', 'Local minimum', 'Continuous', 'Required', 'Result');
    fprintf('  %-18s %14.6f %14.6f %12.6f    %s\n', 'Earth', ...
        v.min_earth_altitude_km, c.min_earth_altitude_km, minimum(1), ...
        verdict(continuous_clearance(1)));
    fprintf('  %-18s %14.6f %14.6f %12.6f    %s\n', 'Moon', ...
        v.min_moon_altitude_km, c.min_moon_altitude_km, minimum(2), ...
        verdict(continuous_clearance(2)));
    fprintf('  Allowed altitude shortfall [m] : %.6g\n', 1000*t.position_km);
end

fprintf('\n[Orb2DS] Transfer result\n\n');
switch result.status
    case 'transfer_found'
        fprintf('  Outcome                        : Transfer found\n');
    case 'candidate_available'
        fprintf('  Outcome                        : Candidate available\n');
    otherwise
        fprintf('  Status                         : %s\n', result.status);
end
answers = {'NO', 'YES'};
fprintf('  Physical acceptance required   : %s\n', answers{1 + require_pass});
stage = 'NONE';
if isfield(result.solver, 'selected_stage') && ~isempty(result.solver.selected_stage)
    stage = result.solver.selected_stage;
end
fprintf('  Selected stage                 : %s\n', stage);
if ismember(stage, {'delta_v', 'delta_v_best_feasible'}) && isfield(result.solver, 'converged')
    termination = {'STOPPED', 'CONVERGED'};
    fprintf('  Selected delta-v solve         : %s\n', termination{1 + result.solver.converged});
end
if ~isempty(result.solution)
    record = result.solution;
    fprintf('  Accepted solution              : YES\n');
    fprintf('  Returned record                : solution\n');
    fprintf('  Delta-v [m/s]                  : %.6f\n', record.metrics.delta_v_m_s);
elseif ~isempty(result.candidate)
    record = result.candidate;
    fprintf('  Transfer record                : result.candidate\n');
    fprintf('  Candidate delta-v [m/s]        : %.6f\n', record.metrics.delta_v_m_s);
else
    fprintf('  Accepted solution              : NONE\n');
    fprintf('  Returned record                : NONE\n');
end
if isfield(result.validation, 'checks')
    v = result.validation;
    fprintf('  Requested ECI vinf [km/s]      : [% .9g, % .9g, % .9g]\n', v.requested_vinf_eci_km_s);
    fprintf('  Local achieved vinf [km/s]     : [% .9g, % .9g, % .9g]\n', v.achieved_vinf_eci_km_s);
    if show_validation
        failed = fieldnames(v.checks);
        failed = failed(~cell2mat(struct2cell(v.checks)));
        if ~isempty(failed)
            fprintf('  Failed physical checks         : %s\n', strjoin(failed, ', '));
        end
    else
        if ~v.is_feasible
            fprintf('  Physical criteria              : Outside acceptance limits\n');
        end
    end
end
end

function residuals(labels, values, limits, scales)
%RESIDUALS Compare in stored units and convert values for display only.
passed = values <= limits;
for index = 1:numel(labels)
    fprintf('  %-30s %12.6g %12.6g    %s\n', labels{index}, ...
        scales(index) * values(index), scales(index) * limits(index), verdict(passed(index)));
end
end

function text = verdict(passed)
%VERDICT Give boolean checks a readable, consistent label.
labels = {'FAIL', 'PASS'};
text = labels{1 + logical(passed)};
end
