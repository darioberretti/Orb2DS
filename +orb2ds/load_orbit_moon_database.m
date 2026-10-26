function database = load_orbit_moon_database(filename)
%LOAD_ORBIT_MOON_DATABASE Explicitly read and validate a canonical encounter file.
%
% PROTOTYPE:
%   database = orb2ds.load_orbit_moon_database(filename)
% INPUT:
%   filename  MAT file containing the schema-1 variable database.
% OUTPUT:
%   database  Validated in-memory descriptor and encounter arrays. Physical
%             units are km, km/s, days and normalized departure phase.
%             Historical thesis tables require explicit migration, never
%             relabeling or an automatic conversion here.

data = load(filename, 'database');
assert(isfield(data, 'database'), 'orb2ds:Schema', ...
    'The file must contain the canonical variable database.');
database = orb2ds.internal.check_database(data.database);
end
