function transfer = assemble_powered_transfer(problem, candidate, options)
%ASSEMBLE_POWERED_TRANSFER Assemble a powered guess and measure SOI gaps.
%
%   Return compact rotating CR3BP and inertial Earth-two-body arc recipes,
%   in km, km/s and local days. The two lunar arcs meet at one position
%   with an explicit impulse. Empty means finite assembly failed.
%
%   problem and options are resolved. candidate is a compact powered match
%   from find_legs. Assembly does not use the encounter database.

assert(~isfield(problem.constraints, 'impulse_nodes') || ...
    ~strcmp(problem.constraints.impulse_nodes, 'endpoints'), ...
    'orb2ds:PoweredFlyby', 'Powered patching requires an impulse at lunar perilune.');
model = problem.orbit.model;
peri_time = (candidate.moon_earth.moon_angle_rad - model.moon_angle_ref_rad) * model.time_days;
[inbound, outbound, earth, burn, patch] = ...
    orb2ds.internal.powered_lunar_arcs(problem, candidate, peri_time, options);
transfer = [];
if isempty(inbound)
    return
end

% Repropagate from the actual departure phase, including its selected burn.
timing = patch.timing;
patch = rmfield(patch, 'timing');
orbit_burn = candidate.orbit_moon.delta_v_km_s(:);
scale = [repmat(model.distance_km, 3, 1); repmat(model.velocity_km_s, 3, 1)];
phase_time = timing.phase * problem.orbit.period_days;
departure = orb2ds.internal.propagate(problem.orbit.state_ref ./ scale, ...
    [0, phase_time / model.time_days], model, options) .* scale;
departure(4:6) = departure(4:6) + orbit_burn;
entry_time = inbound.start_days;
exit_time = outbound.end_days;
orbit_arc = struct('kind', 'cr3bp', 'start_days', timing.departure_days, ...
    'end_days', entry_time, 'initial_days', timing.departure_days, 'initial_state', departure);

% Quantify both same-epoch junctions before meshing overwrites their nodes.
orbit_entry = orb2ds.internal.evaluate_arc(orbit_arc, entry_time, model, options);
lunar_entry = orb2ds.internal.evaluate_arc(inbound, entry_time, model, options);
lunar_exit = orb2ds.internal.evaluate_arc(outbound, exit_time, model, options);
earth_exit = orb2ds.internal.frames(earth.initial_state.', exit_time, model, 'to_rotating');
gaps = [lunar_entry - orbit_entry; earth_exit - lunar_exit];
patch.soi_defects = struct('position_km', vecnorm(gaps(:, 1:3), 2, 2), ...
    'velocity_km_s', vecnorm(gaps(:, 4:6), 2, 2));
lunar_delta_v = norm(burn.lunar_km_s);
patch.total_delta_v_km_s = norm(orbit_burn) + lunar_delta_v + norm(burn.earth_eci_km_s);
patch.ranking_cost_km_s = patch.total_delta_v_km_s + ...
    (options.patching.lunar_impulse_weight - 1) * lunar_delta_v;
provenance = candidate.provenance;
provenance.seed_screening = timing;
provenance.powered_patch = patch;
transfer = struct('schema_version', 1, 'orbit', problem.orbit, ...
    'arcs', [orbit_arc; inbound; outbound; earth], ...
    'events', struct('moon_entry_days', entry_time, ...
    'moon_periapsis_days', inbound.end_days, 'moon_exit_days', exit_time, ...
    'earth_periapsis_days', earth.end_days), ...
    'departure_phase', timing.phase, 'wait_days', timing.wait_days, ...
    'departure_impulse_km_s', orbit_burn, 'lunar_impulse_km_s', burn.lunar_km_s, ...
    'terminal_impulse_eci_km_s', burn.earth_eci_km_s, ...
    'integration', options.integration, 'provenance', provenance);
if options.output.display
    fprintf('\n[Orb2DS] Powered initial guess\n\n');
    fprintf('  Departure epoch [days]         : %.9g\n', timing.departure_days);
    fprintf('  Waiting / flight / total [days]: %.6g / %.6g / %.6g\n', ...
        timing.wait_days, timing.transfer_days, timing.total_days);
    fprintf('  Time-cap excess [days]         : %.6g\n', timing.time_excess_days);
    fprintf('  Lunar impulse [m/s]            : %.6g\n', 1000 * norm(burn.lunar_km_s));
    fprintf('  SOI position gaps [km]         : %.6g entry / %.6g exit\n', patch.soi_defects.position_km);
    fprintf('  SOI velocity gaps [m/s]        : %.6g entry / %.6g exit\n', 1000 * patch.soi_defects.velocity_km_s);
end
end
