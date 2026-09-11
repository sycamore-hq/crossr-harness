# Migration

Clean copy from [`sycamore-hq/crossr-skills`](https://github.com/sycamore-hq/crossr-skills).
History stays on skills. This remote is a snapshot plus new work.

| Field | Value |
|-------|-------|
| Source remote | `sycamore-hq/crossr-skills` |
| Source SHA | `5f4e3c7d97dae62de437821b78e149ac0d8be3fa` (`main` at copy, after split-03) |
| Unit | split-04 copy; split-08 dogfood |
| Method | clean copy (no filter-branch). `HARNESS-SPEC.md` §12–13 stripped on copy. |
| Skills copies | deleted from the catalog in split-07 |

Do not treat the copy SHA as a lockfile pin. Pins are published tags.

## Pins (split-08)

```
skills = "v0-last-monolith"
loops  = "v0"
```

`harness-bootstrap` reads the lockfile, clones those tags, copies catalog + loops + harness templates. `--process-only` is how this repo (and the other two products) consume the process without overlaying skill trees.

## Graphs (split-09)

JSON topology lives in `crossr-loops/graphs/` on `main`. Pin `loops = "v0"` does not include it. Bootstrap does not copy `graphs/`. A later loops tag is a named unit, not an accident.

## Copied (split-04)

See the split-04 commit. Product source: spec, scripts, templates minus `/avril` `/axel`, `dashboard-prompt`, `chief-of-staff` (old name; now `portfolio-brief`), `features.schema.json`, bootstrap smoke.

## Added here (not a copy)

- `lockfile.toml` / `lockfile.toml.example` — real tags as of split-08
- `templates/harness/justfile.status` — `status` / `status-html` recipes as docs
- Consumer `AGENTS.md`, `features.json`, `progress.md`, `justfile` (split-08 dogfood)
