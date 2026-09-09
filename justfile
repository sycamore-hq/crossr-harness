default:
    @just --list

init:
    echo "crossr-harness environment ready"

check:
    cargo check --workspace 2>/dev/null || echo "(no Rust crates)"

test:
    @python3 test/test_status_dashboard.py
    @python3 test/test_features_phase.py
    @python3 test/test_pr6.py
    @python3 test/test_pr7.py
    @./test/harness-bootstrap-smoke.sh

# Orchestration status dashboard (in-harness UI)
status:
    @./scripts/status-dashboard

status-html:
    @./scripts/status-dashboard --html
