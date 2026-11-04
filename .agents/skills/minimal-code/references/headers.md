# Script and function headers

Use coherent paragraphs separated by blank comment lines. Follow the language's documentation conventions and preserve repository-required startup statements.

- **Scripts:** explain purpose, default behavior, alternative workflows, and relevant requirements, outputs, and configuration references.
- **Public functions and substantial local helpers:** use a structured header immediately after the declaration. In MATLAB, begin with `%FUNCTION_NAME One-sentence summary.`, then:
  - `PROTOTYPE`: supported calling syntax and useful optional forms.
  - `DESCRIPTION`: purpose, relevant model or method, and important behavior.
  - `INPUT` / `OUTPUT`: each argument's name, shape or type, meaning, and units. Define symbolic dimensions and document relevant struct fields; link a maintained schema for large interfaces. Explain optional arguments' order, accepted values, defaults, and interactions.
- **Tiny local helpers:** a concise summary and any essential interface details suffice.

Align short input/output entries; wrap longer descriptions underneath. Add `NOTES` or `EXAMPLE` only when useful. For scientific interfaces, specify state ordering, frames, normalization, and actual units; describe an STM's mapping. Distinguish dimensionless values from scaled physical quantities.

Verify headers against the implementation and update them with behavior changes. Copy the examples' presentation, not their project-specific facts. Use idiomatic documentation in other languages.

## Script example

```matlab
%% Scientific purpose and instructions
% Reproduce the A1 family, Moon-grazing 2:1 retrograde periodic orbit,
% linear stability, Poincare section, and vertical response from Chapter 3.
%
% The untouched settings below load accepted results installed by
% install_zenodo_data.m and recreate all eight figures in seconds. Select
% workflow = "run_experiment" to recompute the numerical experiments.
% The saved bundle contains a1_reference_rpo.mat, linear_stability.mat,
% poincare_section.mat, and vertical_instability.mat.
%
% Base MATLAB is required. Parallel Computing Toolbox is optional and makes
% the A1 reconstruction faster; serial execution remains supported. A full
% frozen reconstruction takes approximately tens of minutes. Outputs are
% written under outputs/{reference,generated}/01_reference_rpo/ with numbered
% figure filenames. Locally computed reusable MAT results are written
% under results/generated/ when save_computed_results is true.
%
% The scientific settings are frozen in config/reproduction_config.m. See
% README.md and docs/REPRODUCIBILITY.md for the reference/generated distinction.
```

## Public function example

A short implementation still deserves a complete public interface description.

```matlab
function spectral_radius = compute_spectral_radius(multipliers)
%COMPUTE_SPECTRAL_RADIUS Return the largest multiplier magnitude per orbit.
%
% PROTOTYPE:
%   spectral_radius = compute_spectral_radius(multipliers)
%
% DESCRIPTION:
%   Compute the spectral radius from the supplied multipliers for each
%   orbit. Each row is processed independently.
%
% INPUT:
%   multipliers      [N x M]  Real or complex multipliers, with one orbit
%                            per row and M multipliers per orbit. [-]
%
% OUTPUT:
%   spectral_radius  [N x 1]  Largest absolute multiplier for each orbit. [-]
%
% NOTES:
%   N is the number of orbits and M is the number of supplied multipliers,
%   with M >= 1. The function uses the supplied set without removing any
%   trivial multipliers.

spectral_radius = max(abs(multipliers), [], 2);
end
```

## Local helper example

```matlab
function name = local_execution_name(use_parallel)
%LOCAL_EXECUTION_NAME Return the label for a scalar logical execution flag.

if use_parallel
    name = 'parallel';
else
    name = 'serial';
end
end
```
