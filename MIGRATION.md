# Migration

Clean copy from [`sycamore-hq/crossr-skills`](https://github.com/sycamore-hq/crossr-skills).
History stays on skills. This remote is a snapshot plus new work.

| Field | Value |
|-------|-------|
| Source remote | `sycamore-hq/crossr-skills` |
| Source SHA | `5f4e3c7d97dae62de437821b78e149ac0d8be3fa` (`main` at copy, after split-03) |
| Unit | split-04 |
| Method | clean copy (no filter-branch). `HARNESS-SPEC.md` §12–13 stripped on copy. |
| Skills copies | kept until split-07 (dual-publish, then delete) |

Do not treat this SHA as a lockfile pin. Pins are published tags.

## Copied

### Spec (edited on copy)

- `HARNESS-SPEC.md` — §12–13 loop law removed. Replaced with: loops supplied by `crossr-loops`; harness discloses board, tracking, ritual, dashboard command. §10 now names this remote. §4.4 still chooses a pipeline and points at loops for law.

### Scripts (byte-identical)

- `scripts/harness-bootstrap`
- `scripts/status-dashboard`
- `scripts/sync-skills` (lockfile read comes later)
- `scripts/verify-docs`
- `scripts/verify-opencode`

### Templates minus loop prompt bodies

- `templates/harness/AGENTS.md.template`
- `templates/harness/features.json.template`
- `templates/harness/opencode/agent/status.md`
- `templates/harness/opencode/command/status.md`
- `templates/harness/opencode/opencode.jsonc`

### Skills

- `.agents/skills/dashboard-prompt/` (incl. `assets/dashboard-contract-template.md`)
- `.agents/skills/chief-of-staff/`

### Other

- `features.schema.json`
- `test/harness-bootstrap-smoke.sh`

## Added here (not a copy)

- `lockfile.toml.example` — `skills = <tag>` / `loops = <tag>`
- `templates/harness/justfile.status` — `status` / `status-html` recipes as docs

## Intentionally not copied

- `templates/harness/opencode/{agent,command}/{avril,axel}.md` — loops owns these (split-03)
- `scripts/sync-claude-skills` — catalog
- `avril` / `axel` / `brick` / `rust-team-lead` / `orchestrator-prompt` skills — loops
- `agent-harness` skill — catalog (portable how-to; this spec is the CrossR realization)
- BRICK stage skills — catalog
- `justfile` whole — only the status recipes, as a fragment
- `site/`, `book/` — landing (split-05)

## Consumers

Until split-06 dual-publish, install from `crossr-skills`. This remote is not yet a pin target.
