function print_constraint_tolerances(nlp, tolerance, native_name, test)
%PRINT_CONSTRAINT_TOLERANCES Report the native threshold and its physical equivalents.
%   The equivalents use Orb2DS residual scaling. For a relative native test
%   they are reference values at the configured threshold. Vector entries
%   describe the Euclidean norm when all scaled components meet that threshold.

a = nlp.constraint_tolerances;
factor = tolerance / 1e-9;
fprintf('\n[Orb2DS] Solver constraint tolerances\n\n');
fprintf('  Constraint tolerance [-]       : %.6g (%s)\n', tolerance, native_name);
fprintf('  Native constraint test         : %s\n', test);
fprintf('\n  Physical equivalents at the configured threshold\n');
fprintf('  %-21s %14s %14s %14s\n', 'Constraint', 'Position [km]', 'Velocity [m/s]', 'Time [s]');
print_row('Segment continuity', factor * a.dynamics.position_km, ...
    1000 * factor * a.dynamics.velocity_km_s, []);
print_row('Departure', factor * a.departure.position_km, ...
    1000 * factor * a.departure.velocity_km_s, []);
print_row('Target velocity', [], 1000 * factor * a.target.velocity_km_s, []);
print_row('Periapsis radial speed', [], 1000 * factor * a.periapsis.radial_velocity_km_s, []);
print_row('Node clearance', factor * a.clearance.altitude_km, [], []);
if ~isempty(nlp.A)
    print_row('Duration caps', [], [], 86400 * factor * a.time_days);
end
end

function print_row(label, position, velocity, time)
%PRINT_ROW Leave the units for unrelated constraints blank in the table.
fprintf('  %-22s %13s %14s %14s\n', label, cell_text(position), cell_text(velocity), cell_text(time));
end

function text = cell_text(value)
%CELL_TEXT Format an applicable physical threshold.
if isempty(value)
    text = '-';
else
    text = sprintf('%.6g', value);
end
end
