# Implementation Progress

## PR 2b — generate .opencode/agent/ from persona sources

- `scripts/generate-opencode-agent` is the single emitter (name map, role-default
  frontmatter, persona-frontmatter pass-through, generated marker).
- `harness-bootstrap` runs it after `copy_agents` + `copy_opencode`. Marked
  files and same-run template copies are overwritten; unmarked files are not.
- `verify-opencode` accepts `mode: subagent` and round-trips any marked agent
  file against its persona source.

## Verification Status
- Tooling: `just test` + shellcheck on the touched scripts
- Reviews: pending
