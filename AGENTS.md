# UniPath LK contributor instructions

## Current project status

This repository currently contains JacHammer's blank-canvas web-app template. UniPath LK's graph, catalogue, planner API, session model, pathway UI, and tests are **not implemented yet**. Treat `docs/architecture.md` and `docs/handoff.md` as intended design and roadmap, not descriptions of working features. Keep changes scoped to the requested task and report checks actually performed.

## Architecture and supported workflow

- Keep one Jac project root and one authoritative `jac.toml`; preserve the JacHammer project identity and generated entrypoints.
- The current configured entry is `main.jac`, importing the client from `frontend.cl.jac`. Follow current Jac 0.34.23 patterns and inspect existing files before changing layout.
- Use Jac for future graph models, traversal, validators, financial rules, planner orchestration, and backend logic; use the supported Jac client approach for UI. Avoid a separate Python API, external graph/vector database, or mandatory external database for the starter.
- Before non-trivial Jac edits, consult compiler guides (`jac guide jac-core-cheatsheet`, `jac guide jac-types`, and relevant endpoint, persistence, walker, client, or testing guides). Check the exact local CLI commands and dependencies rather than assuming another Jac release's syntax.
- Keep source and configuration needed for local development in the repository. Never commit keys, real `.env` files, private runtime state, dependency directories, or build output.

## Non-negotiable data and safety invariants

1. Catalogue facts and evidence are separate from private session-specific student state.
2. Every session operation enforces ownership on the server. A supplied session ID alone is never authority.
3. Stable-ID seeding is idempotent and never overwrites planning sessions. Do not expose a public reset/seed endpoint.
4. Use actual graph traversal for candidate pathways. Traverse only education transitions; evidence links are not pathway steps. Bound search, stop cycles, keep candidate branch state isolated, check all AND prerequisites, and preserve meaningful route alternatives including direct routes.
5. Unknown eligibility, fees, duration, or transition evidence stays unknown and requires confirmation. Never turn an unknown into zero, a verified pass, a guaranteed exemption, or an admission/employment promise.
6. Admission, progression, and credit exemption are distinct. Framework comparability does not imply admission or credit rights.
7. Demonstration fixtures must be fictional, visibly labeled **Demonstration data — not verified admission guidance**, and never presented as real education advice. Add real data only with current official, claim-specific evidence.
8. Keep upfront costs/payment timing distinct from recurring costs. Do not presume income, loans, scholarships, jobs, or monthly payment of upfront fees. Distinguish secured funds from assumptions.
9. Changed profile, budget, or preferences invalidate stale results and require an explicit rerun/revision.
10. LLM output is a proposal, not authority. If added, use Jac `by llm()`, constrain and validate actions server-side, enforce small action/time/retry limits, and provide a clearly labeled `rules_fallback` without credentials or on provider failure. Do not fabricate reasoning or events.

## Checks and changes

Run checks appropriate to the files changed using the installed Jac CLI; record actual commands and outcomes. Routine tests must not require external LLM credentials. For endpoint contract changes, check both server and client imports. Avoid changing platform-generated settings without confirming the supported schema. Never claim runtime, build, security, data-verification, or deployment success without having performed it.

For documentation work, keep claims aligned with the actual repository, distinguish current behavior from planned behavior, and state uncertainty plainly. `README.md` is the local start guide; `docs/architecture.md` defines intended boundaries; `docs/handoff.md` records status and the GitHub/JacHammer round trip. `CLAUDE.md` points back to these shared rules.
