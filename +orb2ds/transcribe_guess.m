function guess = transcribe_guess(problem, seed, supplied)
%TRANSCRIBE_GUESS Decode the exact initial NLP vector into compact physical data.
%
% PROTOTYPE:
%   guess = orb2ds.transcribe_guess(problem, seed, options)
%
% DESCRIPTION:
%   Use the same layout, impulse regularization, timing interpretation and
%   bound projection as optimize_transfer. No optimization, remeshing or
%   solver dependency is required. The result is an initialization, not a
%   feasibility claim; reconstruct each CR3BP shooting arc to inspect defects.
%
% INPUT:
%   problem  Current orbit, target and constraints; database is not read.
%   seed     Compatible compact physical guess or previous solution.
%   options  Optional numerical settings, shared with optimize_transfer.
% OUTPUT:
%   guess    Compact physical node record [km, km/s, days]. Never contains
%            optimizer vectors, callbacks or sampled trajectories.

if nargin < 3
    supplied = struct();
end
options = orb2ds.internal.options(supplied);
nlp = orb2ds.internal.build_nlp(problem, seed, options);
guess = orb2ds.internal.record_from_vector(nlp.initial, nlp);
end
