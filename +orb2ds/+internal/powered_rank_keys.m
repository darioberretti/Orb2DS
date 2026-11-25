function keys = powered_rank_keys(timing, phase_error, cost)
%POWERED_RANK_KEYS Return ordered comparison columns for powered leg pairs.
%   The first three columns bound pruning. Lunar epoch mismatch and flight
%   duration break ties. Costs are in km/s and durations are in days.

keys = [timing.time_excess_days, phase_error > 1e-10, cost, ...
    timing.moon_phase_mismatch_rad, timing.transfer_days];
end
