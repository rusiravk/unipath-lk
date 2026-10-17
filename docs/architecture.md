# UniPath LK architecture

## Current state

This repository is currently a JacHammer blank-canvas web-app template, not an implemented pathway planner. `main.jac` renders `frontend.cl.jac`; the existing UI primitives and Tailwind theme are template scaffolding. There are no UniPath graph models, catalogue fixtures, planner endpoints, session rules, or tests yet. This document describes the intended design for the next implementation phase; it is not evidence that those systems already exist.

## Intended boundaries

Keep one Jac project root and one authoritative `jac.toml`. Organize future application code by responsibility using Jac-supported modules:

- **Models:** typed qualification, course offering, evidence, planning session, candidate plan, transition, and event records.
- **Catalogue and fixtures:** stable-ID, idempotent demonstration graph, explicitly separate from any reviewed real catalogue.
- **Graph search:** bounded Jac walker over education-transition edges; evidence relationships support claims but are never pathway steps.
- **Rules and costing:** deterministic eligibility and cost calculations, isolated candidate state, explicit unknowns, and explainable outcomes.
- **Planner:** a small typed action interface; optional `by llm()` proposes only validated actions. Server-controlled search and rules remain authoritative.
- **API:** server endpoints validate input, enforce session ownership, resume clarification, and return typed results/events.
- **UI:** accessible client components call the backend and render the profile, clarification, graph, results, and activity events.
- **Tests:** deterministic checks for graph, validators, cost recalculation, ownership, fallback, and idempotent seeding.

Use Jac's native graph persistence for the starter; do not add an external database or separate API server unless a later reviewed requirement justifies it. Confirm current persistence configuration and runtime behavior before documenting it as a guarantee.

## Data and graph invariants

Qualifications retain stable IDs and separate nullable SLQF and NVQ values. Comparability does not confer admission, progression, or credit-exemption rights. Course offerings identify programme, institution/campus, intake, mode, duration, award, entry rules, and itemized costs; unavailable data stays unknown, not zero.

Evidence records identify the source, URL when applicable, title, specific supported claim, checked date, and applicable version/intake. A reviewed real claim requires its own evidence. Demonstration fixtures use fictional names and are labeled **Demonstration data — not verified admission guidance** in the UI.

Model `Requires`, `Awards`, `ProgressesTo`, and `SupportedBy` (or equivalent explicit Jac relationship types). Keep admission, progression, and exemption distinct. Unknown transition evidence yields `needs_confirmation`; it never becomes verified by default.

Each candidate branch carries its own acquired qualifications, unmet conditions, elapsed time, costs, assumptions, and evidence. AND prerequisites must all hold. A hypothetical course completion is conditional, not a claim that the student completed it. Bound traversal depth and candidate count, prevent cycles, deduplicate equivalent routes without erasing meaningful differences in state or cost, and retain direct routes for comparison.

Catalogue facts are shared; student profile, preferences, budget critiques, and evaluations are session state. Every session read/write must establish server-side ownership or an equally strong isolated guest capability. A client-provided identifier by itself is never authorization. Seed by stable ID and never overwrite planning sessions.

## Planning and API flow

1. Client submits an editable profile and goal to a server endpoint.
2. Server validates fields and establishes an owned planning session/revision.
3. Bounded graph search finds candidate routes; if a material answer is missing, return one pending clarification and persist the resumable session state.
4. The client submits the clarification against that same authorized session. The server updates the profile revision and searches again.
5. Deterministic validators produce one of `feasible_under_stated_assumptions`, `conditional`, `needs_confirmation`, or `not_feasible_under_current_inputs`, with reasons, costs/unknowns, evidence, and next actions.
6. A changed budget or preference invalidates prior findings and triggers an explicit rerun. Results must not silently reuse an older profile revision.
7. Return genuine recorded events for the UI activity log; never fabricate agent deliberations or successful actions.

The exact request/response schemas and status/error shapes must be documented alongside implemented endpoints once established. This repository does not yet implement an API contract.

## Optional LLM and truthful fallback

Without an application-owned provider key, report `planner_mode = rules_fallback` and run deterministic search/validation. If LLM planning is added, use Jac `by llm()` with structured allowed actions and observations; validate every action, ID, and argument against the current session/catalogue before execution. Keep a three-decision initial action limit, a total time budget, timeout handling, and at most one transient retry. Preserve state while waiting for a student answer. Never expose secrets to client code or logs; configure provider secrets through JacHammer environment settings or a local ignored environment file.

## Costs, uncertainty, and ranking

Represent upfront amounts and payment timing separately from recurring costs. Show known, estimated, and unknown costs separately, plus monthly funding gaps and initial cash needs. Unknown costs do not imply affordability. Do not assume scholarships, loans, jobs, internships, or income; distinguish confirmed funds from explicit assumptions. Apply hard constraints before preference ranking, and never imply guaranteed admission, exemption, employment, or affordability.

Real catalogue entries are out of scope until current official sources and claim-level evidence have been checked. The initial fixture is a software demonstration, not education advice.
