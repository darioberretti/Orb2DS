function nodes = node_table(transfer)
%NODE_TABLE Return every node's epoch and rotating impulse in readable units.
%
% PROTOTYPE:
%   nodes = orb2ds.node_table(result)
%   nodes = orb2ds.node_table(record)
%
% DESCRIPTION:
%   Select result.solution when present, otherwise result.candidate. A compact
%   seed/solution/candidate can also be passed directly. Include zero impulses;
%   no propagation is performed and no data are added to the input or saved.
%
% INPUT:
%   transfer  Orb2DS result or compact node record.
% OUTPUT:
%   nodes     Table: Node, Epoch_days, DeltaVx_m_s, DeltaVy_m_s, DeltaVz_m_s,
%             DeltaV_m_s. Components use barycentric rotating axes. An empty
%             result without a record returns an empty table with these columns.

validateattributes(transfer, {'struct'}, {'scalar'});
if isfield(transfer, 'solution')
    record = transfer.solution;
    if isempty(record)
        record = transfer.candidate;
    end
else
    record = transfer;
end
names = {'Node', 'Epoch_days', 'DeltaVx_m_s', 'DeltaVy_m_s', 'DeltaVz_m_s', 'DeltaV_m_s'};
nodes = array2table(zeros(0, 6), 'VariableNames', names);
if ~isempty(record)
    record = orb2ds.internal.check_record(record);
    impulse = 1000 * record.nodes.delta_v_km_s;
    count = numel(record.nodes.time_days);
    nodes = array2table([(1:count).', record.nodes.time_days, impulse, vecnorm(impulse, 2, 2)], ...
        'VariableNames', names);
end
nodes.Properties.VariableUnits = {'', 'days', 'm/s', 'm/s', 'm/s', 'm/s'};
nodes.Properties.Description = 'All shooting nodes; impulse components in barycentric rotating axes.';
end
