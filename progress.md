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
- `./test/harness-bootstrap-smoke.sh` PASS
  - `--process-only` writes `v1-gan-layers` / `v1-no-rtl`
  - full bootstrap cloned those tags; no `! orphan persona` on a fresh target
  - generated `axel.md` is the lean conductor (`axel` + `gan-verdict`); no `rust-team-lead` skill
- Conductor window at these pins: 19,280 bytes (axel 18,148 + gan-verdict 1,132)
- `rust-team-lead` remainders in this tree: `verify-docs` featured-set (site/3c), `MIGRATION.md` history, smoke fixture dummies, this log

## PR 4 follow-on — pin loops to v1-cards; generate avril.md

- `lockfile.toml` + `lockfile.toml.example`: `loops = "v1-cards"` (skills pin
  unchanged). Closes the 4a/4b window: fresh bootstraps were still cloning
  `v1-no-rtl` (no `avril-conductor-agent`, unmarked `avril.md` from the old
  template).
- README + bootstrap header: `avril.md` is generated; `status.md` is the
  remaining hand-written default. Pre-v1-cards unmarked `avril.md` stays until
  deleted by hand (never-overwrite).
- Smoke: `--process-only` writes `v1-cards`; full bootstrap asserts generated
  `avril.md` (`mode: primary`, `avril` + `gan-verdict`); unmarked keep moved
  to `status.md`; generated `avril.md` regenerates.

## Verification Status
- `./test/harness-bootstrap-smoke.sh` PASS
  - `--process-only` writes `v1-gan-layers` / `v1-cards`
  - full bootstrap cloned those tags; no `! orphan persona` on a fresh target
  - generated `avril.md` is primary (`avril` + `gan-verdict`); mutation discarded on regen
  - unmarked keep is `status.md`; fixture-planted handwritten `avril.md` still untouched
- Conductor window at these pins: 7,121 bytes (axel 5,989 + gan-verdict 1,132)

## dashboard-phase — totals() count phase-level in_progress

`totals()` flattened commit items only. A phase left `in_progress` after every
child commit completed printed 100% done and 0 in progress. That is the live
shape of `gan-layer-separation` here, in loops, and in skills.

- `feature_units()`: commits are the units; a phase whose state is not among
  its commit states is also a unit. No double-count when a child is already
  active. Empty pending / completed phases count as themselves.
- `work_units()` is the shared source for headline totals, HTML cards, and
  portfolio "in progress right now".
- `open_phase_features()` lists that phase as unfinished, with the phase
  itself as the outstanding item.
- Defaults already map `in_progress` → active. No `dashboard.config.json`.
- Contract: `docs/status-dashboard-contract.md`.
- Did not close `gan-layer-separation`. That is `gan-close-4b` (work#6).

## Verification Status
- `python3 test/test_status_dashboard.py` — 9 tests OK
- `./test/harness-bootstrap-smoke.sh` — PASS
- Live proof (features.json, no board):
  - harness: was 3/0/0, now 4/1/0 (3 gan commits + this commit done; gan-layer-separation active)
  - loops: was 5/0/0, now 6/1/0 (phase0 empty-completed now counts; gan-layer-separation active)
  - skills: was 94/0/0, now 94/1/0 (gan-layer-separation active)
  Record: 3 in_progress phases, 0 in_progress commits, 102 completed commits.
- Board: none (pinto not installed). Defaults map `in_progress` → active; no config file.
