# Rules for Building UniPath LK with Jac

These rules are for coding agents working in this repository. Read this file together with [AGENTS.md](AGENTS.md) before making changes. `AGENTS.md` is the shared project policy; this file focuses on a friction-light Jac workflow. For current architecture intent and handoff, see [docs/architecture.md](docs/architecture.md) and [docs/handoff.md](docs/handoff.md).

## 1. Establish the actual project state

- This repository currently has JacHammer blank-canvas scaffolding, not a finished UniPath LK planner. Inspect `jac.toml`, `main.jac`, `frontend.cl.jac`, and the relevant source before coding. Do not assume proposed features, endpoints, fixtures, or tests already exist.
- Preserve the single project root, JacHammer-generated project identity, and valid entrypoints. Do not scaffold a second project over this one or guess platform configuration keys.
- Confirm the installed compiler with `jac --version`. The current project environment is reported as Jac 0.34.23; use the local version and guides as authoritative.
- Before non-trivial Jac changes, read the relevant installed guides, for example `jac guide jac-core-cheatsheet`, `jac guide jac-types`, `jac guide jac-fullstack-patterns`, `jac guide jac-sv-endpoints`, `jac guide jac-sv-persistence`, `jac guide jac-walker-patterns`, and `jac guide jac-cl-components`. Do not rely on syntax from another release.

## 2. Keep changes small and verifiable

1. State the requested change and inspect the files it affects.
2. Follow existing module layout and current JacHammer patterns; do not add a framework, database, or package without a clear requirement.
3. Implement the smallest complete behavior, including input bounds, meaningful unknown/error states, and tests where appropriate.
4. Run the relevant installed Jac checks and tests; verify the UI/backend flow in the preview when a user-facing path changes.
5. Report the exact checks performed and any remaining limitations. Never claim a build, test, preview, Git operation, data review, or deployment that was not actually completed.

Use Jac for planned backend models, graph traversal, deterministic rules, costs, and orchestration. Use the supported Jac client approach for the UI. Keep the initial project free of a separate Python API server, external graph/vector database, and mandatory external database.

## 3. Jac client/server boundaries

- Follow the current compiler guides for import and placement rules. Keep server functions on the server and UI components in the client; do not guess module paths or RPC syntax.
- `main.jac` is the configured entrypoint. Inspect its current routing/client composition before changing it. Preserve working generated entrypoints.
- Use typed server/client contracts. Await asynchronous client-to-server calls and handle loading, empty, and error outcomes explicitly.
- Keep secrets server-side. Never embed provider keys in frontend code, committed files, fixtures, or logs. Configure real application secrets through JacHammer Settings or an ignored local environment file.
- Routine deterministic tests must not require external LLM credentials.

## 4. UniPath LK data and recommendation rules

- Treat shared catalogue facts, evidence, and private student planning state as different concerns.
- Session IDs supplied by clients do not prove ownership. Enforce access server-side on every session read and write; use an explicitly safe guest capability if guest planning is supported.
- Seed only stable-ID demonstration/catalogue records idempotently. Seeding must not overwrite student sessions. Do not expose a public seed/reset operation.
- Use genuine bounded Jac graph traversal for pathways. Traverse education transitions, not evidence links. Prevent cycles, cap depth and candidate count, keep route state branch-local, and check every AND prerequisite. Preserve useful direct routes and alternatives with distinct assumptions/costs.
- Keep admission, progression, and credit exemption separate. Framework comparability does not establish admission or exemptions. A hypothetical earlier step is conditional on completion; it is not a completed qualification.
- Unknown information stays unknown. Unknown eligibility or transition evidence requires confirmation, not a pass or rejection. Use explicit outcomes: `feasible_under_stated_assumptions`, `conditional`, `needs_confirmation`, and `not_feasible_under_current_inputs`.
- Do not invent fees, requirements, deadlines, cutoffs, transferred credits, scholarships, jobs, loans, or guarantees. Keep upfront and recurring costs distinct; identify unknown costs, funding gaps, and initial cash needs. Never assume income or financing is secured.
- Demonstration records must be fictional and the UI must prominently say **Demonstration data — not verified admission guidance**. Do not add real catalogue claims until current official sources and claim-specific evidence have been checked.
- Profile, preference, or budget changes invalidate old results and must trigger an explicit new evaluation/revision.

## 5. Optional LLM planning

Only add LLM behavior when requested and supported by the implementation plan. Use Jac `by llm()` with structured, restricted actions; do not add a hand-rolled provider HTTP client or separate LLM SDK. The model may propose an action, but server code validates identifiers, arguments, permissions, and state before execution. Keep tool execution and deterministic validators server-controlled. Enforce documented action/time/retry limits and preserve session state while waiting for a clarification. Without a configured application key, or on a bounded provider failure, use deterministic behavior and accurately label `planner_mode = rules_fallback`. Never fabricate agent activity or expose private reasoning transcripts.

## 6. Tests and documentation

As relevant to the change, test direct and multi-step routes, all-of prerequisites, unknown transitions, clarification/resume, budget recalculation, cycle termination, idempotent seed, session isolation, and missing-key fallback. Keep tests deterministic and independent of real admissions data and external services. Document implemented API payloads and status/error shapes from actual code; do not describe planned contracts as already implemented.

Keep README and handoff statements factual. If measured source-language proportions are reported, state the counting method and exclude dependencies, generated files, assets, documentation, and data; otherwise say **Not measured**.

## 7. GitHub and deployment boundaries

Use JacHammer's Git panel for repository connection and push/pull when operating in JacHammer. For local work, use branches and reviewed diffs and merge only into the agreed integration branch. Before returning to JacHammer, pull and confirm the intended branch/commit. Do not change repository visibility, create a remote, enable automatic production deployment, or deploy without explicit authorization. Distinguish temporary sandbox deployment from permanent production deployment according to the actual platform options.
