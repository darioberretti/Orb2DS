function state = output_file_state(filename)
%OUTPUT_FILE_STATE Snapshot exact existing bytes, distinguishing absent/empty files.
state = [];
if ~isfile(filename)
    return
end
file = fopen(filename, 'rb');
assert(file >= 0, 'orb2ds:OutputRead', 'Cannot inspect existing output: %s.', filename);
cleanup = onCleanup(@() fclose(file));
state = struct('contents', fread(file, Inf, '*uint8'));
end
