function tests = test_flyby_geometry
%TEST_FLYBY_GEOMETRY Independently verify the physical asymptote definitions.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
old_path = path;
addpath(root);
testCase.TestData.cleanup = onCleanup(@() path(old_path));
testCase.TestData.model = orb2ds.earth_moon_model();
end

function testPerigeeCircleProducesRequestedOutgoingVector(testCase)
gm = testCase.TestData.model.gm_earth_km3_s2;
targets = [2, 0, 0; 1, -2, 0.4; -2, 1, -0.2];
for index = 1:size(targets, 1)
    [positions, velocities] = orb2ds.internal.rp_circle_from_vinfplus( ...
        targets(index, :), 8000, gm, 12);
    verifyLessThan(testCase, max(abs(sum(positions .* velocities, 2))), 1e-8);
    for sample = 1:size(positions, 1)
        outgoing = orb2ds.internal.outgoing_asymptote( ...
            positions(sample, :), velocities(sample, :), gm);
        verifyLessThan(testCase, norm(outgoing - targets(index, :).'), 1e-12);
    end
end
end

function testLocalEntryIsNotAnAsymptote(testCase)
model = testCase.TestData.model;
gm = model.gm_moon_km3_s2;
rp = 5000;
speed = 0.8;
periapsis = [rp; 0; 0; 0; sqrt(speed^2 + 2 * gm / rp); 0];
rhs = @(~, x) [x(4:6); -gm * x(1:3) / norm(x(1:3))^3];
options = odeset('RelTol', 1e-13, 'AbsTol', 1e-14, ...
    'Events', @(t, x) sphere_event(t, x, model.encounter_radius_km));
arc = ode113(rhs, [0, -500000], periapsis, options);
verifyNotEmpty(testCase, arc.xe);
entry = arc.ye(:, end);
omega = 1 / (86400 * model.time_days);
state = [[(1 - model.mu) * model.distance_km; 0; 0] + entry(1:3); ...
    entry(4:6) - omega * cross([0; 0; 1], entry(1:3))];
[local, incoming] = orb2ds.internal.moon_asymptote(state.', model);
eccentricity = 1 + rp * speed^2 / gm;
expected = speed / eccentricity * [1, sqrt(eccentricity^2 - 1), 0];
verifyGreaterThan(testCase, norm(local), speed);
verifyLessThan(testCase, norm(incoming - expected), 1e-10);
verifyEqual(testCase, norm(incoming), speed, 'AbsTol', 1e-10);
end

function [value, terminal, direction] = sphere_event(~, state, radius)
value = norm(state(1:3)) - radius;
terminal = 1;
direction = 0;
end
