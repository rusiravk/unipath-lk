# UniPath LK: Implementation Task Plan

**Reference:** `docs/architecture.md` (the single architecture doc). It is the scope authority. Older PDFs and the long architecture MD are roadmap material only.
**Goal:** profile → direct and multi-step graph search → four lens findings → one relevant question → recomputed route → evidence and next actions. Bounded live AI with a clearly labelled rules fallback. Deployed on Jac Hammer.

---

## 0. How to use this file (read first)

**Session protocol for every task:**
1. Read `AGENTS.md`, `docs/architecture.md` and this file. Inspect the existing repository before writing code. Keep and verify work that already exists.
2. Do **one task at a time**, in order. Each task lists *Do*, *Files* (logical, so adapt names to the real template) and *Verify*.
3. Run the *Verify* step and observe the result. Only then tick the box.
4. A milestone is ticked only when its **Gate** passes.
5. Commit after each working task or small group. Update the Progress Log (section 9).
6. If blocked for more than a short attempt, record the blocker, apply the cut rules (section 8), and move on. Never fake a result to unblock yourself.

**Hard rules (apply to every task):**
- Use the installed Jac runtime and generated template. **Never guess** syntax, endpoints, versions or commands. Record discovered values in `README.md`.
- No invented institutions, qualifications, exemptions, fees, transitions, verification claims or probabilities.
- The LLM never sets eligibility, writes to the catalogue, or fetches URLs. Deterministic code decides.
- Unknown (`None` in `.jac` code, `null` in JSON) means unknown, never free, zero or "no prerequisite".
- Keep backend code in `main.jac` (plus optional `tests.jac`) in labelled sections; avoid cross-file imports. Copy `list`/`dict` state when spawning branch walkers.
- Walkers must genuinely `visit` nodes (code moves to the data). A coordinator-only fallback is allowed only if the M0.4 spike fails, and it must be disclosed.
- Jac 0.34.23 is authoritative; confirm with `jac --version` and check syntax against the installed guides, never against notes from other releases.
- Guest planning is **request-scoped**: the browser sends the full profile with `conversation_id` and increasing `profile_revision`. No server-side personal storage, no personal data in logs.
- Student findings and colours are never written to shared catalogue nodes.
- Demo (fixture) and real data are never mixed in one result set. Fixture evidence is always labelled `fixture` and never counts as verified.
- One working tree per agent. Claude Code and Codex work sequentially, or on separate branches with one integration owner.
- Scope cuts are marked **deferred**, never ticked as done.

**Placeholders:** `<check>`, `<test>`, `<start>` and `<build>` mean the real commands discovered in M0.2. Replace them in `README.md`.

---

## 1. Milestone order and gates

| ID | Deliverable | Gate |
|---|---|---|
| M0 | Scaffold, runtime spike, Git baseline | Preview runs; branching walker, typed `by llm` and one endpoint verified or blocker recorded |
| M1 | Domain model, fixture, loader | Fixture imports with validated references, no duplicates on re-import |
| M2 | Rule evaluator | T02 and T03 (rule level) pass |
| M3 | Graph search | T01 and T08 pass |
| M4 | Cost ledger, status, ranking | T05 exact numbers pass |
| M5 | Four lens walkers, clarification | T03 question assertion passes; lens output exists per candidate |
| M6 | API and minimal UI, no-key flow | Profile → question → revised result works with no AI key; T13, U01, P01 pass |
| M7 | Bounded planner and Bridge AI | One real action observed; T11, B01, L01 pass (or milestone marked deferred) |
| M8 | Small real IT catalogue | Claim-level evidence recorded for what exists; gaps explicit |
| M9 | Graph UI, evidence, stress deltas | UI matches backend; stale revisions discarded |
| M10 | Deploy and hosted verification | Intended commit works at hosted URL (H01) |
| M11 | Demo and submission materials | Two clean rehearsals; links verified |

M8 (real data) is independent of M5 to M7 and is done in short blocks between them. It must never delay the core flow. Reduce its coverage before delaying anything else.

---

## 2. M0: Scaffold and runtime spike

- [ ] **M0 accepted**

- [x] **M0.1 Inspect the project.** Check the current Jac Hammer project, generated layout, `AGENTS.md`, `CLAUDE.md` and existing code. Initialize only if nothing exists.
  *Verify:* a short written summary of what already exists and what is missing.
- [x] **M0.2 Run the preview and record the runtime.** Record Jac, client and byLLM versions, install/start/check/test/build commands, tested OS, and whether sandbox or permanent deploy is available.
  *Verify:* preview loads; commands recorded in `README.md`.
- [ ] **M0.3 Git baseline.** Connect the GitHub repo and branch. Preserve a single `jac.toml`, the template entrypoint and the Hammer project linkage.
  *Verify:* clean clone builds.
- [x] **M0.4 Branching walker spike.** Build a tiny graph with two branches and a copied state per branch. Confirm walker spawn/visit semantics. Sequential branches driven by a coordinator function are acceptable if isolation holds.
  *Verify:* a test shows branch A's state change does not appear in branch B.
- [ ] **M0.5 Typed `by llm` spike.** One typed call. Observe how output typing, timeout and retry control actually work. If no credentials exist, record this as an AI blocker; do not stop deterministic work.
  *Verify:* a typed result is returned, or the blocker is recorded.
- [x] **M0.6 Endpoint spike.** Expose one generated API operation and call it.
  *Verify:* a response is received; actual route naming recorded.
- [x] **M0.7 Startup initialization and graph rendering.** Confirm where a one-time startup catalogue load can run, and which native Jac client options can render a graph.
  *Verify:* findings recorded in `README.md`.
- [ ] **M0.8 Repo hygiene.** Add `docs/architecture.md`, this `task.md`, `.env.example`, `.gitignore` secret exclusions. Make `CLAUDE.md` point to `AGENTS.md`. Put the invariants from section 0 into `AGENTS.md`.
  *Verify:* no secrets tracked.
- [x] **M0.9 Jac source-counting method.** Record how the 80% handwritten-Jac share will be counted. Confirm the organisers' interpretation when available.
- [ ] **M0.10 Commit the baseline.** Record branch and SHA.

**Gate:** starter runs; critical runtime assumptions have evidence.

---

## 3. M1: Domain model, fixture and loader

- [x] **M1 accepted**

- [x] **M1.1 Catalogue nodes.** Implement `Institution`, `Qualification`, `CourseOffering`, `CareerGoal`, `EvidenceClaim`, plus `EvidenceSource` records.
  *Files:* `main.jac` (models section). *Verify:* `<check>` passes.
- [x] **M1.2 Planning objects.** Implement `StudentProfile`, `RequirementExpr`, `CostItem`, `SearchState`, `CandidatePlan`, `Finding`, `Question`, `DecisionEvent`, `ActionItem` (architecture section 5).
  *Verify:* `<check>` passes; unknown values are nullable.
- [x] **M1.3 Typed edges.** Implement `Offers`, `Awards`, `ProgressesTo`, `SupportsGoal`, `SupportedBy` (entry rules are `RequirementExpr` objects, so there is no `Requires` edge). `ProgressesTo` carries `transition_id`, `transition_type`, `requirements`, `evidence_claim_ids`, `status` and optional validated cost/duration adjustment.
  *Verify:* a tiny graph builds with each edge type.
- [x] **M1.4 Fixture file.** Create `data/demo/catalogue.json` (fictional institutions, qualifications, `fixture` evidence). Required content:
  - Entry qualification `DEMO-Q-ENTRY`; goal `DEMO-GOAL-IT`.
  - **Direct degree:** 12,000 upfront, 6,000/month, 12 months, remote.
  - **Ladder:** Foundation (3 months) → Diploma (3 months) → Top-up degree (6 months). Each step 2,000 upfront and 4,000/month.
  - **Unconfirmed transfer route:** Diploma → transfer with `unreviewed` evidence.
  - **Location-restricted direct option** (for the clarification test).
  - **Second diploma entry** requiring an English qualification as well (AND test).
  - **One back-edge** (cycle test).
  - Living costs assumed covered outside the education budget; state this in the fixture notes.
  *Verify:* file validates against the loader in M1.5.
- [x] **M1.5 Validated loader.** Validate stable IDs, references, rule operators and numeric values. Build the graph from the JSON, constructing every typed edge: `Institution -Offers-> CourseOffering`, `CourseOffering -Awards-> Qualification`, `-SupportsGoal-> CareerGoal`, `-SupportedBy-> EvidenceClaim`, and `ProgressesTo`. Initialize once at startup, not per request. A failed import must leave the previous healthy snapshot active or make readiness fail.
  *Verify:* a bad reference is rejected with a clear error; after import, each node and edge type has at least one instance and is read by search or a lens.
- [x] **M1.6 Snapshot metadata.** `CatalogueSnapshot` with `version`, `mode` (`demo` or `real`), `schema_version`, `content_hash`.
  *Verify:* the hash is stable across runs.
- [x] **M1.7 Idempotent import (T09).** Re-running import creates no duplicate nodes or edges.
  *Verify:* node and edge counts identical after two imports.
- [x] **M1.8 Offering fidelity.** Keep campus, intake and mode on offerings. SLQF and NVQ claims are separate fields with separate evidence. Unknown stays `null`.
  *Verify:* the loader rejects an SLQF value inferred from an NVQ value (no such inference code exists).
- [ ] **M1.9 Commit.**

**Gate:** the fixture loads once, references validate, re-import is stable.

---

## 4. M2: Rule evaluator

- [x] **M2 accepted**

- [x] **M2.1 Expression types.** Allowlisted `all`, `any`, and typed predicates: qualification possession, subject grade, same-sitting passes, stream, location permission, study mode, available cash. No `eval` or string rules.
  *Verify:* an unknown operator is rejected at load time.
- [x] **M2.2 Three-valued logic.** `pass`, `fail`, `unknown` with the truth tables from architecture section 8.
  *Verify:* a unit table covers `all` and `any` with mixed children.
- [x] **M2.3 Inventory semantics.** A qualification absent from a *declared complete* inventory is absent (fail). A qualification not yet asked about is unknown. Add an inventory-completeness marker to the profile.
  *Verify:* the same missing qualification gives `fail` when complete, `unknown` when not.
- [x] **M2.4 Findings.** Each evaluation returns a `Finding` with rule ID, result, entity, required/actual values, evidence IDs and a short explanation. Keep `predicate_result` separate from `evidence_status`.
  *Verify:* a rule met by user data but with `fixture` evidence reports both separately.
- [x] **M2.5 Tests T02 and T03 (rule level).** T02: the AND prerequisite missing means failure even though an incoming edge exists. T03: an unanswered field yields `unknown`.
  *Verify:* `<test>` passes both.
- [ ] **M2.6 Commit.**

**Gate:** T02 and T03 (rule level) pass.

---

## 5. M3: Graph search

- [x] **M3 accepted**

- [x] **M3.1 Goal ancestors.** From the goal, resolve relevant awards, offerings and incoming progression ancestors within the depth limit.
  *Verify:* the relevant set for `DEMO-GOAL-IT` contains the direct, ladder and transfer offerings.
- [x] **M3.2 Entry states.** Evaluate entry offerings against the profile. Pass or unknown starts a route. Known failure is retained as a blocked finding.
  *Verify:* a profile lacking the English qualification blocks the second diploma entry with a recorded finding.
- [x] **M3.3 Branch walker.** One walker per branch that `visit`s `ProgressesTo` edges, with a copied `SearchState` (fresh `list`/`dict` copies per child). A coordinator-scheduled hop is a fallback only if the M0.4 spike failed, and is disclosed. Provisionally complete a step, attach its award and conditions, then explore eligible `ProgressesTo` edges.
  *Verify:* the M0.4 isolation test still passes on real state.
- [x] **M3.4 Visited signature.** Branch-local signature = current offering + accumulated qualifications + transition history + applicability conditions. No global visited-course set.
  *Verify:* two valid routes through the same offering are both kept.
- [x] **M3.5 Limits.** Defaults: 4 steps, 100 expanded states, 20 candidates, 3 displayed. Deterministic ordering. Set `search_truncated` when a limit is hit.
  *Verify:* a limit of 1 expansion sets the flag.
- [x] **M3.6 Whole-plan revalidation.** Revalidate every step and transition, then the complete candidate, before ranking. Future awards stay conditional on completion and never alter the real profile.
  *Verify:* a route with a stale step fails revalidation.
- [x] **M3.7 Decision events.** Log actual branch rejections and alternative explorations as `DecisionEvent`s. Do not fabricate a retracing animation.
  *Verify:* the blocked second-diploma branch produces an event naming the blocked step.
- [x] **M3.8 Tests T01 and T08.** T01: direct and multi-step both found. T08: the back-edge terminates; branches do not contaminate each other.
  *Verify:* `<test>` passes both.
- [ ] **M3.9 Commit.**

**Gate:** T01 and T08 pass.

---

## 6. M4: Cost ledger, status and ranking

- [x] **M4 accepted**

- [x] **M4.1 Money type.** Integer LKR with a single documented rounding point.
- [x] **M4.2 Event ledger.** Month 0 starts the first course. Per month: subtract upfront costs → record minimum → add month-end contribution (and declared income) → subtract recurring costs → record minimum.
  *Verify:* a hand-computed 2-month example matches.
- [x] **M4.3 Outputs.** Known total cost, nominal duration, minimum balance, maximum recurring gap, and `additional_initial_cash_needed = max(0, -minimum_balance)`.
  *Verify:* values returned as separate fields.
- [x] **M4.4 Unknowns.** An unknown essential amount or timing makes the ledger incomplete. An incomplete ledger never claims affordability.
  *Verify:* a null cost item yields `needs_confirmation` with a cost finding. (T15)
- [x] **M4.5 Route status.** Precedence: known hard failure → `not_feasible_under_current_inputs`; material unknown → `needs_confirmation`; future completion or selection → `conditional`; otherwise `feasible_under_stated_assumptions`. Keep all findings.
  *Verify:* one candidate per status exists in a constructed test.
- [x] **M4.6 Exemptions.** Apply an exemption's cost or duration effect only when an explicit mapped effect exists.
  *Verify:* an exemption with no mapped effect changes nothing. (T16)
- [x] **M4.7 Ranking.** Group by status first. Within a group, keep non-dominated options on known total cost, nominal duration and study-mode fit. No score for unknown values. Deterministic tie-break by route fingerprint. At most three distinct plans.
  *Verify:* a blocked route never outranks an eligible one.
- [x] **M4.8 T05 fixture numbers.**

| Case | Total LKR | Minimum balance | Extra initial cash |
|---|---:|---:|---:|
| Direct degree; savings 2,000; contribution 5,000/month | 84,000 | -22,000 | 22,000 |
| Ladder (Foundation → Diploma → Top-up); same profile | 54,000 | 0 | 0 |
| Direct degree; savings 24,000 | 84,000 | 0 | 0 |

  *Verify:* `<test>` matches exactly. Ladder stays `conditional`.
- [ ] **M4.9 Commit.**

**Gate:** T05 passes with exact numbers.

---

## 7. M5 to M7: Lenses, API, planner

### M5: Four lens walkers and clarification

- [x] **M5 accepted**

All three deterministic lens walkers traverse the graph (`visit` offerings) and inspect each node with a walker ability; none loops over a list from `Root`.

- [x] **M5.1 Aspiration lens.** Goal, study-mode and duration fit findings from supported facts only.
- [x] **M5.2 Fiscal lens.** Cash status, minimum balance, shortfall and unknown-cost findings from the cost engine.
- [x] **M5.3 Gatekeeper lens.** Requirement status and claim-specific evidence references.
- [x] **M5.4 Bridge lens (deterministic form).** Consume existing candidate routes and emit repair proposals with deterministic ordering. LLM ranking is added in M7.
- [x] **M5.5 Request-local findings.** Collect all lens findings in a request-local list keyed by candidate and node/edge. Nothing is written to shared nodes.
  *Verify:* after two different requests, catalogue nodes are unchanged.
- [x] **M5.6 Clarification shortlist.** Candidate questions come only from missing fields referenced by relevant rules. Utility = how many surviving candidates it could change, blocker severity, effort to answer. Offer one question at a time. Skipped fields are not asked again in the same conversation; a profile edit clears the skip.
  *Verify:* a complete profile asks nothing; the location-restricted option triggers a relocation question only when it matters.
- [x] **M5.7 T03 question assertion.** Unknown entry field leads to a relevant question.
  *Verify:* `<test>` passes.
- [ ] **M5.8 Commit.**

**Gate:** all four lens outputs exist; the question test passes.

### M6: API and minimal UI

- [ ] **M6 accepted**

- [x] **M6.1 Operations.** Implement `get_app_info`, `get_catalogue_projection`, `plan_pathways`, `get_evidence`, `health` using the template's real mechanism. The sixth operation, `run_stress_test`, is staged to M9.8; all six are required for release unless the stress cut is recorded. Document the actual names and routes in `README.md`.
  *Verify:* each operation responds.
- [x] **M6.2 Input validation.** Bounded text lengths, arrays, numeric ranges and enumerations; reject unknown catalogue IDs. Error codes `INVALID_PROFILE`, `CATALOGUE_CHANGED`, `REQUEST_LIMIT_EXCEEDED`, `INTERNAL_ERROR`.
  *Verify:* oversized and malformed inputs return non-sensitive errors.
- [x] **M6.3 Recompute everything.** Ignore client-supplied cost, status or prior results. A zero-feasible result is a valid `ready` result, not an error.
  *Verify:* T13 passes.
- [x] **M6.4 Response contract.** `schema_version`, `request_id`, `conversation_id`, `profile_revision`, `profile_hash`, catalogue info, `run_status`, `planner_mode`, `fallback_reason`, `pending_question`, `candidates`, `blocked_candidates`, `decision_events`, `warnings`, `search_truncated`, `metrics`.
  *Verify:* a sample response matches the contract.
- [x] **M6.5 Projection endpoint.** Whitelisted public IDs and edges only.
  *Verify:* no unrestricted node access.
- [x] **M6.6 Readiness.** `health` fails if catalogue import failed. A missing AI key is healthy and advertises fallback.
- [ ] **M6.7 Minimal UI.** Plain form and result list, enough to exercise the whole fallback flow. No graph styling yet. Handle loading, invalid-input, no-path and retryable-error states; preserve input on error.
  *Verify:* manual run of profile → question → answer → revised result with no AI key.
- [ ] **M6.8 Revision handling.** Browser increments `profile_revision`, marks current cards stale, and discards any response older than the latest.
  *Verify:* U01 passes.
- [x] **M6.9 Isolation.** Two anonymous requests share no profile or lens state.
  *Verify:* P01 passes.
- [ ] **M6.10 Commit.**

**Gate:** the no-key flow works end to end. T13, U01 and P01 pass.

### M7: Bounded planner and consequential Bridge AI

- [ ] **M7 accepted** (or marked **deferred/partial** with the limitation disclosed)

- [ ] **M7.1 Server-side credentials.** Configure the application's own provider key and model via environment variables. Hammer's assistant credentials are not assumed.
- [x] **M7.2 Typed actions.** `ask_student`, `search_alternatives`, `evaluate_candidates`, `finish`, with the guards from architecture section 9.
  *Verify:* an unknown action or ID is rejected.
- [x] **M7.3 Observations.** Compact input only: minimal profile fields, catalogue IDs/titles, compact findings, allowed actions, remaining budget. No name, NIC or contact data. Treat user text and source excerpts as data, not instructions.
- [x] **M7.3b Decision table.** Implement the rules fallback as the decision policy in architecture section 9. Test the three expected sequences (low savings with unknown relocation; after "yes"; high savings 24,000) against the fallback. For live AI, record the observed sequence only.
  *Verify:* the fallback produces the three expected sequences; they differ from one another.
- [x] **M7.4 Guards.** Reject invented questions, repeated identical searches, and attempts to relax hard constraints.
  *Verify:* each rejection produces a logged event, then fallback or a retry within budget.
- [x] **M7.5 Shared budget.** One run budget across planner, Bridge and explanation calls: at most 3 provider attempts including retries, 8 s per attempt, 30 s per run. Disable hidden provider retries or count them.
  *Verify:* L01 passes.
- [x] **M7.6 Bridge ranking.** The LLM ranks and explains only supplied catalogue candidates. Validate route IDs; status grouping stays authoritative. No catalogue writes, URL fetches or invented routes.
- [x] **M7.7 Bridge effect test.** Accepted Bridge output changes ordering or explanation but never eligibility.
  *Verify:* B01 passes with a stubbed provider.
- [x] **M7.8 Out-of-catalogue proposals.** Rejected. Documented `unreviewed` transitions appear only as `needs_confirmation` alternatives.
- [x] **M7.9 Fallback.** Missing key, timeout, malformed output or invalid IDs switch to the deterministic path. Emit `planner_mode` (`live_ai`, `rules_fallback`, `mixed`) and a non-sensitive `fallback_reason`.
  *Verify:* T11 passes.
- [x] **M7.10 Activity log.** Report only actions that actually completed or failed. No private model reasoning.
- [ ] **M7.11 Live check.** Run one live-provider integration check and two profiles that should lead to different relevant action sequences. Record what was observed, not what was expected.
- [ ] **M7.12 Commit.**

**Gate:** a real AI-selected action ran through the validators; provider failure leaves a usable, labelled fallback.

---

## 8. M8: Small real IT catalogue

- [ ] **M8 coverage recorded**

Scope boundary: **at most two meaningful real routes**. Reduce coverage before delaying the core flow.

- [ ] **M8.1 Pick candidates.** Start from official sources for SLIATE HNDIT, UCSC BIT, UoM BIT, UNIVOTEC B.Tech or NAITA/VTA IT offerings, as relevant. Names in the architecture are leads, not verified facts.
- [ ] **M8.2 Capture evidence.** For each claim: exact official URL, excerpt, checked date, programme/intake applicability, status.
- [ ] **M8.3 Populate only supported facts.** Missing fees and timings stay `null`. Never copy fees from the old PDFs.
- [ ] **M8.4 Encode requirements.** Express each entry rule as a typed expression and record how it corresponds to the source text.
- [ ] **M8.5 Edges.** Create a `ProgressesTo` edge only for an officially documented transition. An unsupported possibility is an advisor question, never a route edge.
- [ ] **M8.6 Keep distinctions.** UCSC and UoM BIT stay separate offerings. Campus, mode and intake variants stay distinct. SLQF and NVQ claims stay separate.
- [ ] **M8.7 Validate import.** Load `data/real/catalogue.json` through the same loader. Inspect at least one accepted, blocked or unknown case.
- [ ] **M8.8 Record coverage.** Number of routes, claims, and verified vs unreviewed vs unknown. If thin, run a fixture-led demo with the real catalogue as a separate, partially reviewed view.

**Gate:** every real record has a traceable claim-level status; gaps are explicit.

---

## 9. M9: Graph UI, evidence and stress scenarios

- [ ] **M9 accepted**

- [ ] **M9.1 Profile form.** Responsive: goal, qualifications, savings, monthly contribution, relocation, study mode. Pending question card.
- [ ] **M9.2 Graph rendering.** Render nodes and edges from the backend projection only, including alternatives and excluded branches.
  *Verify:* every drawn node and edge exists in the projection.
- [ ] **M9.3 Status styling.** Red / amber / green with text or icons as well. Evidence styling is separate: fixture badge and DEMO banner must not hide blocked or conditional status.
- [ ] **M9.4 Node and edge details.** Click shows the rule, route context, four lens findings and evidence. Show "not applicable" when a lens has no finding.
- [ ] **M9.5 Route cards.** Up to three: steps, cost breakdown (known / estimated / unknown), duration, assumptions, conditions, evidence links, last-checked date, next actions. Support fewer or zero.
- [ ] **M9.6 Activity and mode.** Show actual decision events, backtracking events, planner mode and fallback reason. Update highlights on each revised result.
- [ ] **M9.7 Stale and error handling.** Discard stale revisions; preserve input on errors. The UI formats backend values and never computes eligibility or totals.
- [x] **M9.8 `run_stress_test` operation.** Same deterministic engine, a *copy* of the profile and scenario, the same catalogue snapshot. The baseline is never mutated.
  *Verify:* S01: only scenario inputs change.
- [x] **M9.9 Travel +40%.** Modify explicit travel cost items only. Unknown travel stays unknown; no travel gives a disclosed zero delta. Use a separate labelled stress fixture containing a travel item, with deltas computed by hand in the test (do not alter the T05 numbers).
- [x] **M9.10 Six-month delay.** Document which costs and contributions continue during the gap and show those assumptions. Do not infer intake availability, inflation or new fees.
- [ ] **M9.11 Deltas display.** Absolute cost, shortfall and duration deltas; "unknown" where inputs are incomplete. No survival or probability percentage.
- [ ] **M9.12 Smoke checks.** Revision and stale-response checks, stress recalculation, and a recorded backup of the working flow before deployment work starts.
- [ ] **M9.13 Commit.** Freeze new features after this; deployment follows.

**Gate:** graph, cards and lens notes agree with backend results; stress results are reproducible and assumption-labelled. If stress is cut, mark it **deferred**.

---

## 10. M10: Deployment and release verification

- [ ] **M10 accepted**

- [ ] **M10.1 Release tests.** Run the full test set; record exact commands, counts and failures. Fix correctness and privacy failures first.
- [ ] **M10.2 Push.** Commit and push the integration branch. Record the SHA and catalogue version.
- [ ] **M10.3 Return to Hammer.** Stop concurrent chat edits, pull the intended branch in the same project, and verify the SHA. Do not rely on auto-pull.
- [ ] **M10.4 Configure and deploy.** Set server secrets without printing them, run the preview smoke flow, then deploy via the account's supported option. No auto-production deploy by default.
- [ ] **M10.5 Hosted smoke (H01).** In a fresh session: readiness → profile → graph → question → revised route → evidence and banner.
- [ ] **M10.6 No-key check.** Verify fallback in a controlled configuration, then restore the intended settings. Never show credentials.
- [ ] **M10.7 Release note.** Deployed URL (and expiry if temporary), runtime version, commit SHA, catalogue version, rollback target.

**Gate:** the intended release works at the hosted URL. A preview or localhost recording is a backup, not proof of deployment.

---

## 11. M11: Demo and submission

- [ ] **M11 ready**

- [ ] **M11.1 Script.** Six beats: setup (DEMO banner) → fiscal conflict → multi-step route → clarification and replan → stress deltas (if kept) → real catalogue and close.
- [ ] **M11.2 Real question.** Use a genuinely missing field for the clarification. Do not script a question against a complete profile.
- [ ] **M11.3 Comparison framing.** Show direct-only vs multi-step results. Do not claim SQL cannot do equivalent search.
- [ ] **M11.4 Jac walkthrough.** A short source walkthrough as supporting material; keep the main video within 2-3 minutes.
- [ ] **M11.5 Measured metrics.** Constraint violations with denominator, real-claim evidence coverage, extra routes found, elapsed time, provider attempts, search limits. Fixture evidence is excluded from real coverage. No unmeasured numbers.
- [ ] **M11.6 Rehearse and record.** Two clean runs; label the environment (hosted, preview or local) in each recording.
- [ ] **M11.7 README and handoff.** Actual commands, scope cuts, data mode, tests run, live-AI status, deployment and known limitations.
- [ ] **M11.8 Submit.** Confirm the organiser's requirements, submit, and save the confirmation and final SHA. Verify repository, deployment and video links are accessible.

---

## 12. Required test register

All seven core tests plus targeted extras. Report skipped checks and reasons.

| ID | Assertion | Milestone | Result |
|---|---|---|---|
| T01 | Direct and multi-step candidates found | M3 | Not run |
| T02 | Missing AND prerequisite cannot pass from an incoming edge alone | M2 | Not run |
| T03 | Unknown field stays unknown and produces a relevant question | M2 / M5 | Not run |
| T05 | Fixture totals and shortfalls match M4.8 | M4 | Not run |
| T08 | Cycles terminate; branch state isolated | M3 | Not run |
| T11 | No key / timeout gives labelled fallback | M7 | Not run |
| T13 | Tampered client result ignored; server recomputes | M6 | Not run |
| T09 | Repeat import creates no duplicates | M1 | Not run |
| T15 | Unknown cost gives no affordability claim | M4 | Not run |
| T16 | Exemption without mapped effect changes nothing | M4 | Not run |
| B01 | Stubbed Bridge output changes ordering/explanation, not eligibility | M7 | Not run |
| U01 | Older revision cannot overwrite newer result | M6 | Not run |
| P01 | Anonymous requests do not leak profile or lens state | M6 | Not run |
| L01 | One real provider action within the shared call/time budget | M7 | Not run |
| S01 | Stress run changes only scenario inputs; deltas correct (if kept) | M9 | Not run |
| H01 | Hosted end-to-end flow, labels and fallback | M10 | Not run |

---

## 13. Scope-cut rules (no schedule; apply in this order when blocked)

1. **Stress test:** defer the scenario operation and UI.
2. **Real data:** reduce to one route, never fabricate missing facts.
3. **Live planner:** keep the deterministic fallback; mark M7 deferred/partial and disclose that the agentic behaviour was not demonstrated.
4. **Graph polish:** simplify layout and animation; keep a functional graph, lens notes and evidence interaction.

**Never cut:** graph search, rule correctness, cash ledger, four lens findings (deterministic form is acceptable), deployment, demo rehearsal.

| Deferred feature | Reason | README and demo updated |
|---|---|---|
| None recorded | | |

---

## 14. Release definition of done

- [ ] Hosted URL completes profile → graph → relevant question → revised result.
- [ ] Key-unavailable behaviour works and is visibly labelled rules fallback.
- [ ] Direct vs multi-step comparison and four lens findings are visible.
- [ ] Every shown route has an evidence status; conditional and unknown are distinguishable.
- [ ] No invented institutions, transitions, fees, verification claims or probabilities.
- [ ] Tests pass, with actual results and skipped checks recorded.
- [ ] Live-AI and stress completion or deferral disclosed accurately.
- [ ] Demo rehearsed, backup recorded, submission confirmed.

---

## 15. Progress log and handoff

```text
Current milestone / task:
Repository / integration branch:
Latest working commit:
Runtime and tested commands:
Hammer preview / hosted URL:
Catalogue mode / version:
Real-data coverage so far:
Tests run / live-provider check:
Blocker:
Next action:
```

| Task ID | Commit | Observed check | Blocker or cut | Next |
|---|---|---|---|---|
| | | | | |

**Next coding session:** read `AGENTS.md`, `docs/architecture.md` and this file. Inspect the repository. Complete the earliest unfinished task, run its *Verify* step, update the ticks and this log, then continue. Do not reintroduce roadmap features or unverified data from older documents.
