#!/usr/bin/env bash
# Smoke test for harness-bootstrap (split-08: lockfile pins, no --force).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$SCRIPT_DIR/scripts/harness-bootstrap"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Testing --process-only..."
"$BOOTSTRAP" --process-only "$TMPDIR/proc" > /dev/null
for f in AGENTS.md features.json progress.md justfile lockfile.toml; do
    if [ ! -f "$TMPDIR/proc/$f" ]; then
        echo "✗ process-only missing $f"
        exit 1
    fi
done
if grep -q 'skills = "v0-last-monolith"' "$TMPDIR/proc/lockfile.toml" \
   && grep -q 'loops  = "v0"' "$TMPDIR/proc/lockfile.toml"; then
    echo "✓ process-only wrote tracking files + pins"
else
    echo "✗ process-only lockfile pins wrong"
    cat "$TMPDIR/proc/lockfile.toml"
    exit 1
fi

echo "Testing process-only idempotency (keeps AGENTS.md)..."
echo "marker" >> "$TMPDIR/proc/AGENTS.md"
"$BOOTSTRAP" --process-only "$TMPDIR/proc" > /dev/null
if grep -q marker "$TMPDIR/proc/AGENTS.md"; then
    echo "✓ process-only did not overwrite AGENTS.md"
else
    echo "✗ process-only overwrote AGENTS.md"
    exit 1
fi

echo "Testing full bootstrap from pins..."
"$BOOTSTRAP" "$TMPDIR/full" > "$TMPDIR/full.log"
if [ ! -f "$TMPDIR/full/.agents/skills/code-writer/SKILL.md" ]; then
    echo "✗ missing catalog skill code-writer"
    tail -20 "$TMPDIR/full.log"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.agents/skills/avril/SKILL.md" ]; then
    echo "✗ missing loops conductor avril"
    tail -20 "$TMPDIR/full.log"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.opencode/agent/status.md" ]; then
    echo "✗ missing /status from harness"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.opencode/agent/avril.md" ]; then
    echo "✗ missing /avril from loops"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.agents/skills/dashboard-prompt/SKILL.md" ]; then
    echo "✗ missing dashboard-prompt from harness"
    exit 1
fi
if [ ! -f "$TMPDIR/full/HARNESS-SPEC.md" ]; then
    echo "✗ missing HARNESS-SPEC.md"
    exit 1
fi
echo "✓ full bootstrap installed catalog + loops + harness files"

echo "Testing full idempotency (does not clobber .opencode)..."
echo "kept" >> "$TMPDIR/full/.opencode/agent/avril.md"
"$BOOTSTRAP" "$TMPDIR/full" > /dev/null
if grep -q kept "$TMPDIR/full/.opencode/agent/avril.md"; then
    echo "✓ second run kept existing .opencode/agent/avril.md"
else
    echo "✗ second run overwrote .opencode"
    exit 1
fi

echo "Testing unknown --force is rejected..."
if "$BOOTSTRAP" --force "$TMPDIR/x" > /dev/null 2>&1; then
    echo "✗ --force should exit 2"
    exit 1
fi
echo "✓ --force rejected"

echo "✓ All smoke tests passed"
