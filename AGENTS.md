# AGENTS.md

Guidance for agentic coding assistants working in `nix-amd-npu`.

## Scope

- This file applies to the full repository tree.
- If a deeper `AGENTS.md` exists in a subdirectory, that file takes precedence for files in its subtree.

## Repository Overview

- Project type: Nix flake (`flake-parts`) for AMD Ryzen AI NPU support.
- Primary language: Nix.
- Main goals:
  - Build XRT and XDNA plugin packages.
  - Provide NixOS module for AMD NPU setup.
  - Provide optional MLIR tooling.

## Environment Assumptions

- Use flakes-enabled Nix.
- Typical platform is `x86_64-linux`.
- Some runtime validations require real AMD NPU hardware (`/dev/accel*`). It is available, test it!
- Unfree package paths require `NIXPKGS_ALLOW_UNFREE=1` when used.

## Core Build Commands

- Build default package:
  - `nix build`
- Build specific package:
  - `nix build .#xrt`
  - `nix build .#xrt-plugin-amdxdna`
  - `nix build .#xrt-amdxdna`
  - `nix build .#mlir-aie`
- Build with logs:
  - `nix build .#<package> --print-build-logs`

## Lint / Format Commands

- Nix format check used in CI:
  - `nix run nixpkgs#nixfmt-rfc-style -- --check flake.nix parts/*.nix lib/*.nix`
- Nix format write:
  - `nix run nixpkgs#nixfmt-rfc-style -- flake.nix parts/*.nix lib/*.nix`
- Note: CI currently warns on formatting; it does not hard-fail.

## Test Commands

### Flake and Integration Checks

- Evaluate flake checks:
  - `nix flake check`
- Fast eval-only check (no builds):
  - `nix flake check --no-build`
- Build a single integration check (important for focused debugging):
  - `nix build .#checks.x86_64-linux.xrt-binaries`
  - `nix build .#checks.x86_64-linux.plugin-library`
  - `nix build .#checks.x86_64-linux.plugin-discovery`
  - `nix build .#checks.x86_64-linux.pkg-config-files`
  - `nix build .#checks.x86_64-linux.environment-setup`
- With logs:
  - `nix build .#checks.x86_64-linux.<check-name> --print-build-logs`

## Dev Shell Commands

- Default shell:
  - `nix develop`
- IRON shells:
  - `nix develop .#iron`
  - `nix develop .#iron-full` (then run `iron-fhs`)

## Code Style: General

- Follow existing style in touched files; keep diffs minimal and focused.
- Do not refactor unrelated code during feature/fix work.
- Prefer explicit, readable code over clever shortcuts.
- Keep comments high-signal; avoid restating obvious operations.
- Preserve existing module/file organization patterns.

## Code Style: Nix

- Formatting:
  - Use 2-space indentation.
  - Use `nixfmt-rfc-style` for edited Nix files when relevant.
- Function argument sets:
  - Keep one identifier per line in multi-line argument lists.
  - Keep trailing commas in multi-line attrsets/lists.
- Naming:
  - Package variables are generally kebab-case (`xrt-plugin-amdxdna`).
  - Local Nix variables are descriptive and consistent with nearby code.
- Derivations:
  - Prefer `stdenv.mkDerivation rec { ... }` conventions already used.
  - Keep `meta` blocks complete (`description`, `homepage`, `license`, `platforms`).
- Patching/build steps:
  - Prefer `substituteInPlace` and explicit patches over opaque shell hacks.
  - Keep `postPatch` and `postInstall` deterministic and commented when non-obvious.

## Error Handling Expectations

- Fail early with clear messages in build/test scripts.
- Prefer explicit assertions/messages in Nix checks (`test ... || (echo ... && exit 1)`).
- In Python CLI paths:
  - Validate user input (paths/options) before expensive work.
  - Print actionable error messages to stderr for user-facing failures.
- Do not silently swallow exceptions unless there is a documented fallback path.

## Validation Strategy for Changes

- For Nix package/module changes:
  - Run the smallest relevant command first (`nix build .#<target>`).
  - Then run broader checks (`nix flake check`) if scope warrants.
- If hardware-dependent tests are not possible, state that explicitly.

## Files and Areas Requiring Extra Care

- `parts/packages.nix`: defines published packages and integration checks.
- `parts/nixos-module.nix`: user-facing NixOS options and defaults.
- `pkgs/xrt/default.nix`: complex patching and install-path behavior.

## Agent Workflow Recommendations

- Before editing, inspect nearby files for local patterns.
- Keep changes scoped; avoid broad formatting-only diffs.
- When introducing new commands in docs, ensure they work from repo root.
- When adding tests/checks, prefer deterministic and non-networked flows.
- Summarize what was validated and what was not validated.

