# UniPath LK

UniPath LK is a free, anonymous pathway-planning tool for Sri Lankan post-A/L students. It searches a typed graph of programmes for **direct and multi-step routes** to a goal, checks every route against the student's stated situation (entry rules, cash flow, evidence), asks at most one relevant clarifying question at a time, and shows what is feasible, conditional, unconfirmed or blocked. It is **not** a source of guaranteed admissions, exemptions, jobs or financial outcomes.

> **Data status:** the only catalogue with records is a **fictional demonstration fixture** (`data/demo/catalogue.json`), shown with the banner *Demonstration data — not verified admission guidance*. The real catalogue (`data/real/catalogue.json`) is intentionally **empty**: no real institution, fee or transition has been source-reviewed yet (task M8 is deferred).

## What is implemented

| Area | Where | Status |
|---|---|---|
| Typed catalogue graph (`Institution`, `Qualification`, `CourseOffering`, `CareerGoal`, `EvidenceClaim`; edges `Offers`, `Awards`, `SupportsGoal`, `SupportedBy`, `ProgressesTo`) built once from JSON, validated, idempotent | `backend.jac` sections 3 and 5 | Implemented, tested |
| Rule evaluator: allowlisted AST, pass / fail / unknown | `backend.jac` section 4 | Implemented, tested |
| Bounded search: one walker per branch with copied state, cycle-safe, limits, decision events | `backend.jac` section 6 | Implemented, tested |
| Cash-flow ledger, route status, ranking | `backend.jac` sections 7 and 8 | Implemented, tested (exact fixture numbers) |
| Four lens walkers (Aspiration, Fiscal, Gatekeeper, Bridge) that `visit` the graph | `backend.jac` section 9 | Implemented, tested |
| One-question clarification shortlist | `backend.jac` section 10 | Implemented, tested |
| Planner: LLM proposes (`by llm`), deterministic table decides, labelled rules fallback | `backend.jac` sections 11 and 12 | Fallback implemented and tested; **live provider path not exercised (no key available)** |
| Six public operations | `backend.jac` section 15 | Implemented, tested in-process and over HTTP |
| Stress test (travel +40%, 6-month delay) | `backend.jac` section 14 | Implemented, tested |
| Web UI: form, question card, graph, route cards, lens notes, evidence, activity log, stress panel | `frontend.cl.jac`, `components/*.cl.jac` | See "Verification" below |

## API

All operations are `def:pub` functions served at `POST /function/<name>` (JSON body, parameters by name). The response is wrapped in the standard envelope (`data.result`).

| Operation | Purpose |
|---|---|
| `get_app_info` | banner, limits, feature flags, whether a live AI key is configured |
| `health` | readiness; `ready` is false if the demo catalogue failed to import (a missing AI key is healthy) |
| `get_catalogue_projection(mode)` | whitelisted nodes and edges with layout hints |
| `plan_pathways(profile, conversation_id, profile_revision, expected_catalogue_hash)` | candidates, excluded options, lens findings, graph states, pending question, decision events, planner mode |
| `get_evidence(claim_id, mode)` | one evidence record |
| `run_stress_test(profile, scenario, conversation_id, profile_revision)` | absolute deltas for `travel_plus_40` or `delay_6_months` |

`profile` is a plain JSON object (see `profile_from_dict` in `backend.jac`); unknown (`null`) means unknown, never zero. Error codes: `INVALID_PROFILE`, `CATALOGUE_CHANGED`, `REQUEST_LIMIT_EXCEEDED`, `INTERNAL_ERROR`. The server recomputes everything; there is no parameter that accepts a client-supplied result.

## Running it

The commands below were run in this repository with **Jac 0.16.7** (the newest release on PyPI), `jac-client 0.3.25`, `jac-super 0.1.22`, `byllm 0.6.19`, Python 3.13, Bun 1.4.3 on Windows 11. JacHammer reports **Jac 0.34.23**, so re-run the checks there before relying on them (see Known limitations).

```bash
pip install jaclang byllm jac-client jac-super   # in a virtual environment
jac install            # npm dependencies via Bun (slow on first run)
jac check backend.jac  # type check
jac test backend.jac   # 41 tests, no API key needed
jac start main.jac --port 8000
```

Set `OPENAI_API_KEY` (and optionally `LLM_MODEL`) in the server environment to enable the live planner. Without a key the planner runs the deterministic decision table and reports `planner_mode: rules_fallback`, `fallback_reason: no_api_key`. Never put keys in source or the browser.

## Runtime findings (M0)

- **Versions.** Local checks used Jac 0.16.7 (newest on PyPI). JacHammer reports 0.34.23. `main.jac` keeps the Hammer template shape and cannot be loaded by 0.16.7 ("relative import with no known parent package"), so `local_entry.jac` is a 0.16-compatible entry that serves the same backend and client. Run it with `jac start local_entry.jac --port 8000`. The Hammer path (`main.jac`) is **unverified here**.
- **Walkers.** Spawning a child walker with `nxt spawn child` inside a walker ability works; each child receives copied `list`/`dict` state, and sibling branches do not affect each other (tests T08, B01).
- **Endpoints.** `def:pub` functions are served at `POST /function/<name>`. Raw REST delivers `obj` parameters as plain dicts, so `plan_pathways` and `run_stress_test` take a plain `profile` object and validate it field by field.
- **Startup initialisation.** Anonymous callers share the guest root, so the catalogue is loaded lazily on first use (`ensure_catalogue`) and reused while its content hash is unchanged. Re-import is idempotent.
- **Graph rendering.** The UI draws an inline SVG from the server projection (`get_catalogue_projection`), which includes layout layers computed in Jac. No graph library is used.
- **`by llm`.** Wired in `backend.jac` (`choose_action_ai`, `rank_bridge_routes`) with `max_output_retries=0` and timeouts enforced by the caller. Not exercised against a real provider because no key was available; tests drive the planner with stub choosers.
- **Counting the Jac share (method, not a measured result).** Count non-blank, non-comment lines in handwritten `*.jac` / `*.cl.jac` files versus handwritten files in other languages. Exclude dependencies, `node_modules`, `.jac/`, generated output, assets, documentation and data (`data/*.json`). Currently all handwritten application logic and UI is Jac; the only non-Jac handwritten files are CSS (`styles/global.css`, from the template) and JSON data. The share has **not been measured or confirmed with the organisers**.

## Verification and limitations

See [docs/handoff.md](docs/handoff.md) and the progress log in [task.md](task.md) for exactly which checks ran and which are still open. In short: backend tests pass locally; the live-provider test, hosted deployment, real-data review (M8) and the 80% Jac measurement are **not done**.

## Documentation

- [docs/architecture.md](docs/architecture.md): scope, design rules and decisions.
- [task.md](task.md): milestone checklist with gates.
- [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md), [rules.md](rules.md): contributor rules and invariants.

## License

No license has been chosen. Choose and add one before describing this repository as openly licensed.
