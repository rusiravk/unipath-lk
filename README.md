# UniPath LK

UniPath LK is planned as a free, openly accessible pathway-planning tool for Sri Lankan post-A/L students. It is intended to help explore education routes under stated constraints, with clear evidence and uncertainty. It is not a source of guaranteed admissions, exemptions, employment, or financial outcomes.

> **Repository status:** this project currently contains JacHammer's blank-canvas web-app template. The UniPath LK planner, graph-backed API, session handling, fixture catalogue, and tests have not yet been implemented. Do not treat this README's product description as a claim of working functionality.

## Current project setup

The checked-in `jac.toml` identifies a Jac web app with `main.jac` as the entry point and configures Tailwind/shadcn client dependencies. The current JacHammer environment reports Jac 0.34.23; check the local CLI version before development and record exact resolved package versions/lock files after the project dependencies are installed. No application-specific runtime command or test suite has been verified in this documentation-only update.

For this existing JacHammer project, use its configured environment and project root. Inspect `jac --version` and `jac --help`, then consult the installed compiler guides before changing source. The starter's existing `AGENTS.md` documents reference-guide and validation commands. Verify the current supported invocation before relying on it; the template documents `jac install` and `jac start --dev`, but they have not been run as part of this documentation update.

## Intended product flow

The planned first vertical slice lets a student enter an editable profile and goal, search an actual Jac graph, answer one material clarification at a time, and receive deterministic feasible/conditional/blocked findings with evidence, cost assumptions, and next actions. Budget or preference changes require a new revision and rerun. A rules-only fallback must work without provider credentials and be labeled `rules_fallback`. Fictional demonstration fixtures must be clearly marked **Demonstration data — not verified admission guidance**. Real catalogue claims require current official, claim-specific evidence.

See [docs/architecture.md](docs/architecture.md) for intended graph, validation, API, and persistence boundaries; see [docs/handoff.md](docs/handoff.md) for implementation status and the GitHub/JacHammer workflow.

## Development and configuration

Keep a single Jac project root and authoritative `jac.toml`. Use Jac for planned backend models, graph traversal, validation, costs, and orchestration, with the supported Jac client for the interface. No separate API server or mandatory external database is part of the starter plan.

When an application-owned LLM provider is implemented, configure its secret in JacHammer Settings for the hosted preview or in a local ignored environment file. Never put keys in frontend code, source control, or logs. Do not assume JacHammer assistant credentials are available to the application. No `.env.example` is provided by this documentation-only change because no application environment contract has been implemented; add one with placeholder names when that contract is defined.

## Verification and limitations

No source build, syntax/type check, test, backend flow, GitHub push/pull, catalogue source review, provider call, or deployment is claimed here. Record exact commands and results when actually run. Product persistence behavior, endpoint payloads, and runtime guarantees remain to be established by implementation and verification.

## License and contributions

Choose and add a project license before describing this repository as openly licensed. For contributions, read [AGENTS.md](AGENTS.md) and preserve its evidence, uncertainty, graph traversal, and session-isolation invariants.
