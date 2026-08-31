# Implementation Progress

## PR 2b — generate .opencode/agent/ from persona sources

- `scripts/generate-opencode-agent` is the single emitter (name map, role-default
  frontmatter, persona-frontmatter pass-through, generated marker).
- `harness-bootstrap` runs it after `copy_agents` + `copy_opencode`. Marked
  files and same-run template copies are overwritten; unmarked files are not.
- Marker ownership is the first non-empty line after frontmatter, not a
  anywhere-in-file grep.
- Orphan-persona warning: a target `*-agent.md` with no counterpart in the
  current pins still generates, but bootstrap prints `! orphan persona`.
  Refreshing personas on pin move remains 2c.
- `verify-opencode` accepts `mode: subagent` and round-trips any marked agent
  file against its persona source.

## Verification Status
- `./test/harness-bootstrap-smoke.sh` PASS including quoted-marker and orphan cases
- Dry-run at `v1-gan-layers` + `v1-runtime-agents` (`4f3e406`): `axel.md`
  primary, 2a load set (`axel` + `gan-verdict`), adversaries subagent,
  `avril.md`/`status.md` unmarked, second run byte-identical
- Conductor window at those pins: 19,816 bytes (axel 18,684 + gan-verdict 1,132)
- shellcheck: `harness-bootstrap` clean
- Reviews: hold (stale sample) + marker anchor + orphan tripwire addressed

## PR 3b — pins to v1-gan-layers / v1-no-rtl; retarget rust-team-lead

- `lockfile.toml` + `lockfile.toml.example`: `v1-gan-layers` / `v1-no-rtl`.
  Closes the skills#108 window (fresh bootstraps were cloning v0 and generating
  the fat pre-2a conductor).
- `HARNESS-SPEC.md`: dropped `rust-team-lead`; `rust-architect` → `architecture`
  (PR 1a name); persona trio → role names at the new loops pin.
- Protected-law SKILL.md edits (one-word-class): `chief-of-staff`,
  `dashboard-prompt` — dropped `rust-team-lead` from the orchestration list.
  `scripts/status-dashboard` docstring same drop (not skill law).
- Smoke `--process-only` assertions follow the new pins. Full-bootstrap now
  also asserts lean conductor (`axel` + `gan-verdict`) and no orphan warnings.

## Verification Status
- pending smoke run against the new tags
