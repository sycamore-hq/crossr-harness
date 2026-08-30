# Implementation Progress

## PR 2b — generate .opencode/agent/ from persona sources

- `scripts/generate-opencode-agent` is the single emitter (name map, role-default
  frontmatter, persona-frontmatter pass-through, generated marker).
- `harness-bootstrap` runs it after `copy_agents` + `copy_opencode`. Marked
  files and same-run template copies are overwritten; unmarked files are not.
- `verify-opencode` accepts `mode: subagent` and round-trips any marked agent
  file against its persona source.

## Verification Status
- Tooling: `./test/harness-bootstrap-smoke.sh` PASS (all generation / marker /
  unmarked-preserve / regenerate / idempotence cases). `just` not installed in
  this environment; `just test` is that script.
- shellcheck: `harness-bootstrap` and the smoke test clean. `verify-opencode`
  still has three pre-existing warnings (SC2164 / SC2181 / SC2016) untouched.
- Dry-run: local skills + loops (`v1-runtime-agents` tag missing). `axel.md`
  primary with conductor body; `avril.md` / `status.md` unmarked and kept.
  Overlaying 2a role names produced `reviewer-agent.md` / `tester-agent.md` /
  `architect-agent.md` as subagents.
- Reviews: pending
