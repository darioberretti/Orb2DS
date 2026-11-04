# Formatting and workflow comments

Use readable blocks with short workflow comments as the default. Apply the principles in the language's normal syntax; the example uses MATLAB.

## Formatting rules

- Separate distinct tasks with one blank line; keep tightly related statements together. Do not insert blank lines mechanically after every statement or control-flow keyword.
- In a multi-stage workflow, place a short comment above each meaningful stage so the reader can scan its purpose without interpreting every call. Comments that summarize a block are useful even when the operations are visible in the code. Avoid comments that merely repeat individual assignments or calls.
- Explain non-obvious intent, domain or mathematical reasoning, invariants, assumptions, units, and subtle constraints beside the relevant code.
- Use ordinary one-line comments for local stages. Reserve section headings for major parts of a script; avoid decorative separators as the default.
- Use the language's conventional spacing and indentation. For MATLAB, use four-space indentation and spaces after commas and around ordinary operators; keep one executable statement per line except repository-required startup lines.
- Aim for code lines around 100 characters and prose comments around 80 characters. Wrap at meaningful boundaries without splitting related arguments awkwardly; these are guides, not hard limits.
- Use short inline comments for units or allowed settings. Put longer explanations above the setting, and align inline comments only within small local groups when useful.

## A body with visible workflow stages

This runner excerpt shows the preferred grouping. Short comments identify tasks, blank lines separate them, and related operations stay together. Existing project utilities are used without introducing helpers just to reduce the runner's length.

```matlab
%% Linear stability

% Compute the stability analysis or load the selected saved result.
stability_filename = fullfile(run_context.result_directory, 'linear_stability.mat');

if run_context.compute
    a1_result = rpo.load_result(a1_filename);
    result = rpo.compute_stability(cfg, a1_result);

    % Attach provenance and compare against the reference result.
    result = rpo.finalize_result(result, cfg, 'run_01_reference_rpo.m', ...
        "a1_reference_rpo.mat", run_context.artifact_type);
    result = rpo.add_reference_comparison('stability', result, fullfile( ...
        repository_root, 'results', 'reference', 'reference_rpo', ...
        'linear_stability.mat'));

    rpo.save_result(result, stability_filename);
else
    result = rpo.load_result(stability_filename);
end

% Report the planar and spatial stability classifications.
fprintf('Linear-stability source: %s\n', stability_filename);

metrics = result.metrics.reference_rpo;
stability_labels = {'linearly unstable', 'linearly stable'};

fprintf('Reference RPO planar rho: %.12f (%s)\n', ...
    metrics.planar_spectral_radius, stability_labels{1 + metrics.planar_stable});
fprintf('Reference RPO spatial rho: %.12f (%s)\n\n', ...
    metrics.spatial_spectral_radius, stability_labels{1 + metrics.spatial_stable});

% Create and export the stability figures.
figures = rpo.plot_stability(result, run_context.figure_visibility);
rpo.export_figures(figures, run_context.output_directory, ...
    run_context.figure_formats);
```

Avoid collapsing this into one uninterrupted block. Also avoid the opposite extreme: a comment or blank line for every assignment, decorative banners for small steps, or a helper for each comment.

## Before finishing

Check that a reader can identify the main stages without reading every statement. Preserve useful whitespace, workflow comments, and local variables when simplifying. Do not extract helpers merely to shorten a visible block.

For a formatting-only edit, verify that executable code is unchanged rather than rerunning expensive experiments without a reason.
