"""UniPath LK backend: typed catalogue graph, rule evaluation, bounded route search,
cash-flow costing, the four lens walkers, the planner and the public API.

Everything server-side lives in this one module on purpose (see docs/architecture.md
section 13): sections are labelled with banner comments.
"""

import json;
import os;
import hashlib;
import time;
import uuid;
import from concurrent.futures { ThreadPoolExecutor }

# ---------------------------------------------------------------------------
# 1. Constants
# ---------------------------------------------------------------------------

glob SCHEMA_VERSION: str = "1";
glob ALLOWED_OPS: list[str] = ["all", "any", "has_qual", "subject_grade", "stream", "location", "study_mode", "min_cash"];
glob GRADE_ORDER: list[str] = ["A", "B", "C", "S", "W", "F"];
glob DEFAULT_MAX_STEPS: int = 4;
glob DEFAULT_MAX_STATES: int = 100;
glob DEFAULT_MAX_CANDIDATES: int = 20;
glob MAX_SHOWN: int = 3;
glob STATUS_ORDER: list[str] = ["feasible_under_stated_assumptions", "conditional", "needs_confirmation", "not_feasible_under_current_inputs"];
glob EVIDENCE_SEVERITY: list[str] = ["verified", "fixture", "unreviewed", "stale", "rejected"];
glob QUESTION_FIELDS: list[str] = ["can_relocate", "savings", "monthly_contribution", "study_mode", "stream"];
glob PLANNER_ACTIONS: list[str] = ["ask_student", "search_alternatives", "evaluate_candidates", "finish"];
glob MAX_PLANNER_ACTIONS: int = 6;
glob MAX_PROVIDER_ATTEMPTS: int = 3;
glob ATTEMPT_SECONDS: int = 8;
glob RUN_SECONDS: int = 30;
glob catalogue_errors: dict[str, str] = {};

# ---------------------------------------------------------------------------
# 2. Plain objects (request-scoped data, never stored on shared nodes)
# ---------------------------------------------------------------------------

obj CostItem {
    has item_id: str;
    has label: str;
    has kind: str;
    has category: str;
    has amount: int | None = None;
    has essential: bool = True;
}

obj RequirementExpr {
    has op: str;
    has value: str | None = None;
    has arg: str | None = None;
    has children: list[RequirementExpr] = [];
}

obj StudentProfile {
    has goal_id: str = "";
    has qualifications: list[str] = [];
    has not_held: list[str] = [];
    has inventory_complete: bool = False;
    has subject_grades: dict[str, str] = {};
    has stream: str | None = None;
    has savings: int | None = None;
    has monthly_contribution: int | None = None;
    has district: str | None = None;
    has can_relocate: bool | None = None;
    has study_mode: str | None = None;
    has skipped_fields: list[str] = [];
    has catalogue_mode: str = "demo";
}

obj Leaf {
    has rule_op: str;
    has data_field: str;
    has required: str;
    has actual: str;
    has result: str;
    has conditional: bool = False;
}

obj Finding {
    has lens: str;
    has candidate_id: str;
    has node_id: str;
    has rule_id: str;
    has result: str;
    has message: str;
    has data_field: str = "";
    has required: str = "";
    has actual: str = "";
    has evidence_ids: list[str] = [];
    has evidence_status: str = "";
}

obj DecisionEvent {
    has seq: int;
    has kind: str;
    has actor: str;
    has message: str;
    has node_id: str = "";
}

obj SearchState {
    has path: list[str] = [];
    has awards: list[str] = [];
    has transitions: list[str] = [];
    has signatures: list[str] = [];
}

obj SearchBudget {
    has max_states: int = 100;
    has max_candidates: int = 20;
    has expanded: int = 0;
    has truncated: bool = False;
    has reasons: list[str] = [];
}

obj RawRoute {
    has offering_ids: list[str];
    has transition_ids: list[str] = [];
}

obj BlockedItem {
    has blocked_id: str;
    has offering_id: str;
    has transition_id: str;
    has path: list[str];
    has message: str;
    has findings: list[Finding] = [];
}

obj OfferingView {
    has offering_id: str;
    has title: str;
    has institution_id: str;
    has institution_name: str;
    has campus: str = "";
    has district: str = "";
    has delivery_mode: str = "";
    has intake: str = "";
    has award_level: str = "";
    has duration_months: int | None = None;
    has is_entry: bool = False;
    has entry_rule: str = "";
    has cost_items: list[CostItem] = [];
    has awards: list[str] = [];
    has goals: list[str] = [];
    has evidence_ids: list[str] = [];
}

obj TransitionView {
    has transition_id: str;
    has from_id: str;
    has to_id: str;
    has transition_type: str;
    has requirements: str = "";
    has evidence_claim_ids: list[str] = [];
    has status: str = "fixture";
    has duration_delta_months: int | None = None;
    has cost_delta: int | None = None;
    has note: str = "";
}

obj QualificationView {
    has qual_id: str;
    has name: str;
}

obj GoalView {
    has goal_id: str;
    has name: str;
    has min_award_level: str = "";
}

obj ClaimView {
    has claim_id: str;
    has subject: str;
    has status: str;
    has source_title: str = "";
    has source_url: str = "";
    has excerpt: str = "";
    has checked_date: str = "";
    has applies_to: str = "";
}

obj CatalogueView {
    has mode: str;
    has version: str = "";
    has content_hash: str = "";
    has banner: str = "";
    has notes: str = "";
    has offerings: dict[str, OfferingView] = {};
    has transitions: dict[str, TransitionView] = {};
    has qualifications: dict[str, QualificationView] = {};
    has goals: dict[str, GoalView] = {};
    has claims: dict[str, ClaimView] = {};
    has institutions: dict[str, str] = {};
}

obj PlanStep {
    has offering_id: str;
    has title: str;
    has institution_name: str;
    has award_level: str;
    has delivery_mode: str;
    has campus: str;
    has duration_months: int | None;
    has via_transition_id: str = "";
    has via_type: str = "";
    has check_result: str = "pass";
    has check_findings: list[Finding] = [];
    has evidence_status: str = "";
    has evidence_ids: list[str] = [];
    has cost_items: list[CostItem] = [];
}

obj LedgerResult {
    has complete: bool = False;
    has known_total: int = 0;
    has unknown_items: list[str] = [];
    has duration_months: int | None = None;
    has minimum_balance: int | None = None;
    has extra_initial_cash: int | None = None;
    has max_recurring_gap: int | None = None;
    has assumptions: list[str] = [];
}

obj CandidatePlan {
    has plan_id: str;
    has fingerprint: str;
    has route_kind: str;
    has steps: list[PlanStep];
    has status: str;
    has status_reason: str;
    has ledger: LedgerResult;
    has evidence_status: str = "";
    has conditions: list[str] = [];
    has next_actions: list[str] = [];
    has dominated: bool = False;
    has ai_note: str = "";
    has ai_rank: int = -1;
}

obj Question {
    has question_id: str;
    has data_field: str;
    has text: str;
    has answer_type: str;
    has candidates_affected: int = 0;
    has utility: int = 0;
}

obj GraphNodeState {
    has node_id: str;
    has state: str;
    has plan_ids: list[str] = [];
}

obj PlannerRunInfo {
    has planner_mode: str = "rules_fallback";
    has fallback_reason: str = "";
    has provider_attempts: int = 0;
    has actions: list[str] = [];
}

obj PlanResponse {
    has schema_version: str = "1";
    has request_id: str = "";
    has conversation_id: str = "";
    has profile_revision: int = 0;
    has profile_hash: str = "";
    has catalogue_mode: str = "";
    has catalogue_version: str = "";
    has catalogue_hash: str = "";
    has banner: str = "";
    has run_status: str = "ready";
    has error_code: str = "";
    has error_message: str = "";
    has planner_mode: str = "rules_fallback";
    has fallback_reason: str = "";
    has pending_question: Question | None = None;
    has candidates: list[CandidatePlan] = [];
    has blocked_candidates: list[BlockedItem] = [];
    has findings: list[Finding] = [];
    has graph_states: list[GraphNodeState] = [];
    has decision_events: list[DecisionEvent] = [];
    has warnings: list[str] = [];
    has search_truncated: bool = False;
    has metrics: dict[str, int] = {};
    has action_sequence: list[str] = [];
    has bridge_note: str = "";
}

obj PlanDelta {
    has plan_id: str;
    has title: str;
    has baseline_status: str;
    has scenario_status: str;
    has cost_delta: int | None = None;
    has shortfall_delta: int | None = None;
    has duration_delta: int | None = None;
    has note: str = "";
}

obj StressResponse {
    has request_id: str = "";
    has conversation_id: str = "";
    has profile_revision: int = 0;
    has scenario: str = "";
    has run_status: str = "ready";
    has error_code: str = "";
    has error_message: str = "";
    has assumptions: list[str] = [];
    has deltas: list[PlanDelta] = [];
    has baseline: list[CandidatePlan] = [];
    has scenario_plans: list[CandidatePlan] = [];
}

obj ProjNode {
    has node_id: str;
    has label: str;
    has kind: str;
    has detail: str = "";
    has is_entry: bool = False;
    has evidence_status: str = "";
    has layer: int = 0;
    has row: int = 0;
}

obj ProjEdge {
    has edge_id: str;
    has source: str;
    has target: str;
    has kind: str;
    has label: str = "";
    has status: str = "";
}

obj Projection {
    has mode: str;
    has version: str = "";
    has banner: str = "";
    has nodes: list[ProjNode] = [];
    has edges: list[ProjEdge] = [];
}

obj EvidenceRecord {
    has claim_id: str;
    has found: bool = False;
    has subject: str = "";
    has status: str = "";
    has source_title: str = "";
    has source_url: str = "";
    has excerpt: str = "";
    has checked_date: str = "";
    has applies_to: str = "";
}

obj AppInfo {
    has name: str = "UniPath LK";
    has schema_version: str = "1";
    has catalogue_modes: list[str] = [];
    has default_mode: str = "demo";
    has banner: str = "";
    has live_ai_available: bool = False;
    has feature_flags: dict[str, bool] = {};
    has limits: dict[str, int] = {};
}

obj HealthInfo {
    has ready: bool = False;
    has detail: str = "";
    has catalogue_ok: dict[str, bool] = {};
    has live_ai_available: bool = False;
}

# ---------------------------------------------------------------------------
# 3. Graph archetypes (shared catalogue only: no student data is ever stored here)
# ---------------------------------------------------------------------------

node CatalogueSnapshot {
    has mode: str;
    has version: str;
    has schema_version: str;
    has content_hash: str;
    has banner: str = "";
    has notes: str = "";
}

node Institution {
    has inst_id: str;
    has name: str;
    has catalogue_mode: str;
    has district: str = "";
}

node Qualification {
    has qual_id: str;
    has name: str;
    has catalogue_mode: str;
    has slqf_level: int | None = None;
    has nvq_level: int | None = None;
    has slqf_claim_id: str = "";
    has nvq_claim_id: str = "";
}

node CareerGoal {
    has goal_id: str;
    has name: str;
    has catalogue_mode: str;
    has min_award_level: str = "";
}

node EvidenceClaim {
    has claim_id: str;
    has subject: str;
    has status: str;
    has catalogue_mode: str;
    has source_title: str = "";
    has source_url: str = "";
    has excerpt: str = "";
    has checked_date: str = "";
    has applies_to: str = "";
}

node CourseOffering {
    has offering_id: str;
    has title: str;
    has institution_id: str;
    has catalogue_mode: str;
    has campus: str = "";
    has district: str = "";
    has delivery_mode: str = "";
    has intake: str = "";
    has award_level: str = "";
    has duration_months: int | None = None;
    has is_entry: bool = False;
    has entry_rule: str = "";
    has cost_items: list[CostItem] = [];
    has evidence_ids: list[str] = [];
}

edge Offers: Institution --> CourseOffering {}

edge Awards: CourseOffering --> Qualification {}

edge SupportsGoal: CourseOffering --> CareerGoal {}

edge SupportedBy: CourseOffering --> EvidenceClaim {}

edge ProgressesTo: CourseOffering --> CourseOffering {
    has transition_id: str;
    has from_id: str;
    has to_id: str;
    has transition_type: str = "progression";
    has requirements_json: str = "";
    has evidence_claim_ids: list[str] = [];
    has status: str = "fixture";
    has duration_delta_months: int | None = None;
    has cost_delta: int | None = None;
    has note: str = "";
}

# ---------------------------------------------------------------------------
# 4. Rules: allowlisted AST, three-valued logic, no eval
# ---------------------------------------------------------------------------

def parse_expr(raw: any) -> RequirementExpr {
    if not isinstance(raw, dict) {
        raise ValueError("rule must be an object");
    }
    d = raw as dict[str, any];
    op_raw = d.get("op");
    if not isinstance(op_raw, str) {
        raise ValueError("rule is missing 'op'");
    }
    op = op_raw as str;
    if op not in ALLOWED_OPS {
        raise ValueError(f"unknown rule operator '{op}'");
    }
    if op == "all" or op == "any" {
        kids_raw = d.get("children");
        if not isinstance(kids_raw, list) {
            raise ValueError(f"'{op}' needs a children list");
        }
        kids = kids_raw as list[any];
        if len(kids) == 0 {
            raise ValueError(f"'{op}' needs at least one child");
        }
        parsed: list[RequirementExpr] = [];
        for k in kids {
            parsed.append(parse_expr(k));
        }
        return RequirementExpr(op=op, children=parsed);
    }
    val = d.get("value");
    if not isinstance(val, str) {
        raise ValueError(f"'{op}' needs a string value");
    }
    arg_raw = d.get("arg");
    arg: str | None = None;
    if isinstance(arg_raw, str) {
        arg = arg_raw as str;
    }
    if op == "subject_grade" and (arg is None or arg not in GRADE_ORDER) {
        raise ValueError("subject_grade needs arg as a grade letter");
    }
    if op == "min_cash" {
        try {
            _ = int(val as str);
        } except ValueError {
            raise ValueError("min_cash needs an integer value");
        }
    }
    return RequirementExpr(op=op, value=val as str, arg=arg);
}

def rule_from_json(text: str) -> RequirementExpr | None {
    if text == "" {
        return None;
    }
    return parse_expr(json.loads(text));
}

def grade_index(g: str) -> int {
    if g in GRADE_ORDER {
        return GRADE_ORDER.index(g);
    }
    return len(GRADE_ORDER);
}

def make_leaf(e: RequirementExpr, data_field: str, required: str, actual: str, result: str, conditional: bool, leaves: list[Leaf]) -> str {
    leaves.append(Leaf(rule_op=e.op, data_field=data_field, required=required, actual=actual, result=result, conditional=conditional));
    return result;
}

def eval_expr(e: RequirementExpr, p: StudentProfile, future: list[str], leaves: list[Leaf]) -> str {
    if e.op == "all" or e.op == "any" {
        results: list[str] = [];
        for c in e.children {
            results.append(eval_expr(c, p, future, leaves));
        }
        if e.op == "all" {
            if "fail" in results {
                return "fail";
            }
            if "unknown" in results {
                return "unknown";
            }
            return "pass";
        }
        if "pass" in results {
            return "pass";
        }
        if "unknown" in results {
            return "unknown";
        }
        return "fail";
    }
    val = e.value or "";
    if e.op == "has_qual" {
        if val in p.qualifications {
            return make_leaf(e, "qualification:" + val, val, "held", "pass", False, leaves);
        }
        if val in future {
            return make_leaf(e, "qualification:" + val, val, "awarded by an earlier step", "pass", True, leaves);
        }
        if val in p.not_held {
            return make_leaf(e, "qualification:" + val, val, "student said they do not hold it", "fail", False, leaves);
        }
        if p.inventory_complete {
            return make_leaf(e, "qualification:" + val, val, "not held (list declared complete)", "fail", False, leaves);
        }
        return make_leaf(e, "qualification:" + val, val, "not yet asked", "unknown", False, leaves);
    }
    if e.op == "subject_grade" {
        need = e.arg or "";
        have = p.subject_grades.get(val);
        if have is None {
            if p.inventory_complete {
                return make_leaf(e, "subject:" + val, f"{val} >= {need}", "no grade recorded", "fail", False, leaves);
            }
            return make_leaf(e, "subject:" + val, f"{val} >= {need}", "not yet asked", "unknown", False, leaves);
        }
        if grade_index(have) <= grade_index(need) {
            return make_leaf(e, "subject:" + val, f"{val} >= {need}", have, "pass", False, leaves);
        }
        return make_leaf(e, "subject:" + val, f"{val} >= {need}", have, "fail", False, leaves);
    }
    if e.op == "stream" {
        if p.stream is None {
            return make_leaf(e, "stream", val, "unknown", "unknown", False, leaves);
        }
        if p.stream == val {
            return make_leaf(e, "stream", val, p.stream or "", "pass", False, leaves);
        }
        return make_leaf(e, "stream", val, p.stream or "", "fail", False, leaves);
    }
    if e.op == "location" {
        if p.district is not None and p.district == val {
            return make_leaf(e, "can_relocate", f"based in {val} or willing to relocate", f"based in {val}", "pass", False, leaves);
        }
        if p.can_relocate is None {
            return make_leaf(e, "can_relocate", f"based in {val} or willing to relocate", "relocation not yet answered", "unknown", False, leaves);
        }
        if p.can_relocate {
            return make_leaf(e, "can_relocate", f"based in {val} or willing to relocate", "willing to relocate", "pass", False, leaves);
        }
        return make_leaf(e, "can_relocate", f"based in {val} or willing to relocate", "cannot relocate", "fail", False, leaves);
    }
    if e.op == "study_mode" {
        if p.study_mode is None {
            return make_leaf(e, "study_mode", val, "unknown", "unknown", False, leaves);
        }
        if p.study_mode == val or p.study_mode == "any" {
            return make_leaf(e, "study_mode", val, p.study_mode or "", "pass", False, leaves);
        }
        return make_leaf(e, "study_mode", val, p.study_mode or "", "fail", False, leaves);
    }
    if e.op == "min_cash" {
        need_cash = int(val);
        if p.savings is None {
            return make_leaf(e, "savings", f"savings >= {need_cash}", "unknown", "unknown", False, leaves);
        }
        have_cash = p.savings or 0;
        if have_cash >= need_cash {
            return make_leaf(e, "savings", f"savings >= {need_cash}", str(have_cash), "pass", False, leaves);
        }
        return make_leaf(e, "savings", f"savings >= {need_cash}", str(have_cash), "fail", False, leaves);
    }
    raise ValueError(f"unsupported operator '{e.op}'");
}

def worst_evidence(statuses: list[str]) -> str {
    worst = "verified";
    if len(statuses) == 0 {
        return "";
    }
    for s in statuses {
        if s in EVIDENCE_SEVERITY and EVIDENCE_SEVERITY.index(s) > EVIDENCE_SEVERITY.index(worst) {
            worst = s;
        }
    }
    return worst;
}

def claim_statuses(view: CatalogueView, claim_ids: list[str]) -> list[str] {
    out: list[str] = [];
    for cid in claim_ids {
        c = view.claims.get(cid);
        if c is not None {
            out.append(c.status);
        }
    }
    return out;
}

def leaves_to_findings(leaves: list[Leaf], lens: str, node_id: str, candidate_id: str, rule_id: str, evidence_ids: list[str], evidence_status: str) -> list[Finding] {
    out: list[Finding] = [];
    for lf in leaves {
        msg = f"{lf.required}: {lf.actual}";
        if lf.conditional {
            msg = f"{lf.required}: {lf.actual} (conditional on completing that step)";
        }
        out.append(Finding(
            lens=lens, candidate_id=candidate_id, node_id=node_id, rule_id=rule_id, result=lf.result,
            message=msg, data_field=lf.data_field, required=lf.required, actual=lf.actual,
            evidence_ids=evidence_ids, evidence_status=evidence_status
        ));
    }
    return out;
}

# ---------------------------------------------------------------------------
# 5. Catalogue: validation, one-time idempotent import, read-only views
# ---------------------------------------------------------------------------

def data_path(mode: str) -> str {
    base = os.path.dirname(os.path.abspath(__file__));
    return os.path.join(base, "data", mode, "catalogue.json");
}

def as_int_or_none(v: any, label: str, errors: list[str]) -> int | None {
    if v is None {
        return None;
    }
    if isinstance(v, bool) or not isinstance(v, int) {
        errors.append(f"{label} must be an integer or null");
        return None;
    }
    iv = v as int;
    if iv < 0 {
        errors.append(f"{label} must not be negative");
    }
    return iv;
}

def check_rule(raw: any, label: str, known_quals: list[str], errors: list[str]) {
    if raw is None {
        return;
    }
    try {
        e = parse_expr(raw);
        check_rule_refs(e, label, known_quals, errors);
    } except ValueError as ex {
        errors.append(f"{label}: {str(ex)}");
    }
}

def check_rule_refs(e: RequirementExpr, label: str, known_quals: list[str], errors: list[str]) {
    if e.op == "has_qual" and (e.value or "") not in known_quals {
        errors.append(f"{label}: unknown qualification '{e.value or ''}'");
    }
    for c in e.children {
        check_rule_refs(c, label, known_quals, errors);
    }
}

def validate_catalogue(raw: dict[str, any], mode: str) -> list[str] {
    errors: list[str] = [];
    if raw.get("mode") != mode {
        errors.append(f"file mode is '{raw.get('mode')}' but expected '{mode}'");
    }
    ids: dict[str, str] = {};
    inst_ids: list[str] = [];
    qual_ids: list[str] = [];
    goal_ids: list[str] = [];
    claim_ids: list[str] = [];
    off_ids: list[str] = [];
    for sec in ["institutions", "qualifications", "goals", "evidence", "offerings", "transitions"] {
        if not isinstance(raw.get(sec), list) {
            errors.append(f"missing list '{sec}'");
        }
    }
    if len(errors) > 0 {
        return errors;
    }
    for r in (raw.get("institutions") as list[any]) {
        d = r as dict[str, any];
        rid = str(d.get("id", ""));
        if rid == "" or rid in ids { errors.append(f"duplicate or empty id '{rid}'"); }
        ids[rid] = "institution";
        inst_ids.append(rid);
    }
    for r in (raw.get("qualifications") as list[any]) {
        d = r as dict[str, any];
        rid = str(d.get("id", ""));
        if rid == "" or rid in ids { errors.append(f"duplicate or empty id '{rid}'"); }
        ids[rid] = "qualification";
        qual_ids.append(rid);
    }
    for r in (raw.get("goals") as list[any]) {
        d = r as dict[str, any];
        rid = str(d.get("id", ""));
        if rid == "" or rid in ids { errors.append(f"duplicate or empty id '{rid}'"); }
        ids[rid] = "goal";
        goal_ids.append(rid);
    }
    for r in (raw.get("evidence") as list[any]) {
        d = r as dict[str, any];
        rid = str(d.get("id", ""));
        if rid == "" or rid in ids { errors.append(f"duplicate or empty id '{rid}'"); }
        ids[rid] = "evidence";
        claim_ids.append(rid);
        if str(d.get("status", "")) not in EVIDENCE_SEVERITY {
            errors.append(f"evidence '{rid}' has invalid status");
        }
    }
    for r in (raw.get("offerings") as list[any]) {
        d = r as dict[str, any];
        rid = str(d.get("id", ""));
        if rid == "" or rid in ids { errors.append(f"duplicate or empty id '{rid}'"); }
        ids[rid] = "offering";
        off_ids.append(rid);
    }
    for r in (raw.get("offerings") as list[any]) {
        d = r as dict[str, any];
        rid = str(d.get("id", ""));
        if str(d.get("institution_id", "")) not in inst_ids {
            errors.append(f"offering '{rid}' references unknown institution");
        }
        _ = as_int_or_none(d.get("duration_months"), f"offering '{rid}' duration_months", errors);
        for q in (d.get("awards") or []) as list[any] {
            if str(q) not in qual_ids { errors.append(f"offering '{rid}' awards unknown qualification '{q}'"); }
        }
        for g in (d.get("goals") or []) as list[any] {
            if str(g) not in goal_ids { errors.append(f"offering '{rid}' supports unknown goal '{g}'"); }
        }
        for c in (d.get("evidence_ids") or []) as list[any] {
            if str(c) not in claim_ids { errors.append(f"offering '{rid}' references unknown evidence '{c}'"); }
        }
        for ci in (d.get("cost_items") or []) as list[any] {
            cd = ci as dict[str, any];
            _ = as_int_or_none(cd.get("amount"), f"cost item '{cd.get('id', '')}' amount", errors);
            if str(cd.get("kind", "")) not in ["upfront", "recurring"] {
                errors.append(f"cost item '{cd.get('id', '')}' kind must be upfront or recurring");
            }
        }
        check_rule(d.get("entry_rule"), f"offering '{rid}' entry_rule", qual_ids, errors);
    }
    tids: list[str] = [];
    for r in (raw.get("transitions") as list[any]) {
        d = r as dict[str, any];
        rid = str(d.get("id", ""));
        if rid == "" or rid in ids or rid in tids { errors.append(f"duplicate or empty id '{rid}'"); }
        tids.append(rid);
        if str(d.get("from", "")) not in off_ids or str(d.get("to", "")) not in off_ids {
            errors.append(f"transition '{rid}' references an unknown offering");
        }
        for c in (d.get("evidence_claim_ids") or []) as list[any] {
            if str(c) not in claim_ids { errors.append(f"transition '{rid}' references unknown evidence '{c}'"); }
        }
        _ = as_int_or_none(d.get("duration_delta_months"), f"transition '{rid}' duration_delta_months", errors);
        _ = as_int_or_none(d.get("cost_delta"), f"transition '{rid}' cost_delta", errors);
        if str(d.get("status", "")) not in EVIDENCE_SEVERITY {
            errors.append(f"transition '{rid}' has invalid status");
        }
        check_rule(d.get("requirements"), f"transition '{rid}' requirements", qual_ids, errors);
    }
    return errors;
}

def canonical_hash(raw: dict[str, any]) -> str {
    return hashlib.sha256(json.dumps(raw, sort_keys=True).encode("utf-8")).hexdigest()[:16];
}

def json_or_empty(v: any) -> str {
    if v is None {
        return "";
    }
    return json.dumps(v, sort_keys=True);
}

def cost_items_from(raw_items: any) -> list[CostItem] {
    out: list[CostItem] = [];
    if not isinstance(raw_items, list) {
        return out;
    }
    for ci in (raw_items as list[any]) {
        cd = ci as dict[str, any];
        amt: int | None = None;
        if isinstance(cd.get("amount"), int) {
            amt = cd.get("amount") as int;
        }
        out.append(CostItem(
            item_id=str(cd.get("id", "")), label=str(cd.get("label", "")), kind=str(cd.get("kind", "")),
            category=str(cd.get("category", "")), amount=amt, essential=bool(cd.get("essential", True))
        ));
    }
    return out;
}

def opt_str(v: any) -> str {
    if v is None {
        return "";
    }
    return str(v);
}

def opt_int(v: any) -> int | None {
    if isinstance(v, int) and not isinstance(v, bool) {
        return v as int;
    }
    return None;
}

walker PurgeWalker {
    has mode: str;
    has doomed: list[any] = [];
    has seen: list[str] = [];

    can start with Root entry {
        m = self.mode;
        visit [-->[?:CatalogueSnapshot, mode == m]];
    }

    can snap with CatalogueSnapshot entry {
        self.doomed.append(here);
        visit [-->];
    }

    can any_inst with Institution entry {
        self.doomed.append(here);
        visit [->:Offers:->[?:CourseOffering]];
    }

    can goal with CareerGoal entry {
        if here.goal_id not in self.seen {
            self.seen.append(here.goal_id);
            self.doomed.append(here);
        }
    }

    can qual with Qualification entry {
        if here.qual_id not in self.seen {
            self.seen.append(here.qual_id);
            self.doomed.append(here);
        }
    }

    can claim with EvidenceClaim entry {
        if here.claim_id not in self.seen {
            self.seen.append(here.claim_id);
            self.doomed.append(here);
        }
    }

    can off with CourseOffering entry {
        if here.offering_id in self.seen {
            return;
        }
        self.seen.append(here.offering_id);
        self.doomed.append(here);
        for q in [here ->:Awards:->[?:Qualification]] {
            if q.qual_id not in self.seen {
                self.seen.append(q.qual_id);
                self.doomed.append(q);
            }
        }
        for c in [here ->:SupportedBy:->[?:EvidenceClaim]] {
            if c.claim_id not in self.seen {
                self.seen.append(c.claim_id);
                self.doomed.append(c);
            }
        }
    }
}

def import_catalogue(mode: str, force: bool = False) -> str {
    # Validate, then build the catalogue graph for one mode. Returns "" or an error text.
    # A failed validation leaves the previously imported healthy snapshot untouched.
    path = data_path(mode);
    try {
        with open(path, "r", encoding="utf-8") as fh {
            raw = json.loads(fh.read()) as dict[str, any];
        }
    } except Exception as ex {
        msg = f"cannot read catalogue file for '{mode}': {str(ex)}";
        catalogue_errors[mode] = msg;
        return msg;
    }
    errors = validate_catalogue(raw, mode);
    if len(errors) > 0 {
        msg = "; ".join(errors[:6]);
        catalogue_errors[mode] = msg;
        return msg;
    }
    chash = canonical_hash(raw);
    m = mode;
    existing = [root -->[?:CatalogueSnapshot, mode == m]];
    if len(existing) > 0 and existing[0].content_hash == chash and not force {
        catalogue_errors[mode] = "";
        return "";
    }
    if len(existing) > 0 {
        purge = root spawn PurgeWalker(mode=mode);
        for n in purge.doomed {
            del n;
        }
    }
    snap = CatalogueSnapshot(
        mode=mode, version=str(raw.get("version", "")), schema_version=str(raw.get("schema_version", "")),
        content_hash=chash, banner=str(raw.get("banner", "")), notes=str(raw.get("notes", ""))
    );
    root ++> snap;
    inst_nodes: dict[str, Institution] = {};
    for r in (raw.get("institutions") as list[any]) {
        d = r as dict[str, any];
        n = Institution(inst_id=str(d.get("id")), name=str(d.get("name", "")), catalogue_mode=mode, district=opt_str(d.get("district")));
        snap ++> n;
        inst_nodes[n.inst_id] = n;
    }
    qual_nodes: dict[str, Qualification] = {};
    for r in (raw.get("qualifications") as list[any]) {
        d = r as dict[str, any];
        qn = Qualification(
            qual_id=str(d.get("id")), name=str(d.get("name", "")), catalogue_mode=mode,
            slqf_level=opt_int(d.get("slqf_level")), nvq_level=opt_int(d.get("nvq_level")),
            slqf_claim_id=opt_str(d.get("slqf_claim_id")), nvq_claim_id=opt_str(d.get("nvq_claim_id"))
        );
        snap ++> qn;
        qual_nodes[qn.qual_id] = qn;
    }
    goal_nodes: dict[str, CareerGoal] = {};
    for r in (raw.get("goals") as list[any]) {
        d = r as dict[str, any];
        g = CareerGoal(goal_id=str(d.get("id")), name=str(d.get("name", "")), catalogue_mode=mode, min_award_level=opt_str(d.get("min_award_level")));
        snap ++> g;
        goal_nodes[g.goal_id] = g;
    }
    claim_nodes: dict[str, EvidenceClaim] = {};
    for r in (raw.get("evidence") as list[any]) {
        d = r as dict[str, any];
        cn = EvidenceClaim(
            claim_id=str(d.get("id")), subject=str(d.get("subject", "")), status=str(d.get("status", "")), catalogue_mode=mode,
            source_title=opt_str(d.get("source_title")), source_url=opt_str(d.get("source_url")),
            excerpt=opt_str(d.get("excerpt")), checked_date=opt_str(d.get("checked_date")), applies_to=opt_str(d.get("applies_to"))
        );
        snap ++> cn;
        claim_nodes[cn.claim_id] = cn;
    }
    off_nodes: dict[str, CourseOffering] = {};
    for r in (raw.get("offerings") as list[any]) {
        d = r as dict[str, any];
        ev_ids: list[str] = [];
        for c in (d.get("evidence_ids") or []) as list[any] {
            ev_ids.append(str(c));
        }
        o = CourseOffering(
            offering_id=str(d.get("id")), title=str(d.get("title", "")), institution_id=str(d.get("institution_id")), catalogue_mode=mode,
            campus=opt_str(d.get("campus")), district=opt_str(d.get("district")), delivery_mode=opt_str(d.get("delivery_mode")),
            intake=opt_str(d.get("intake")), award_level=opt_str(d.get("award_level")), duration_months=opt_int(d.get("duration_months")),
            is_entry=bool(d.get("is_entry", False)), entry_rule=json_or_empty(d.get("entry_rule")),
            cost_items=cost_items_from(d.get("cost_items")), evidence_ids=ev_ids
        );
        off_nodes[o.offering_id] = o;
        inst_nodes[o.institution_id] +>:Offers:+> o;
        for q in (d.get("awards") or []) as list[any] {
            o +>:Awards:+> qual_nodes[str(q)];
        }
        for g in (d.get("goals") or []) as list[any] {
            o +>:SupportsGoal:+> goal_nodes[str(g)];
        }
        for c in ev_ids {
            o +>:SupportedBy:+> claim_nodes[c];
        }
    }
    for r in (raw.get("transitions") as list[any]) {
        d = r as dict[str, any];
        cids: list[str] = [];
        for c in (d.get("evidence_claim_ids") or []) as list[any] {
            cids.append(str(c));
        }
        off_nodes[str(d.get("from"))] +>:ProgressesTo(
            transition_id=str(d.get("id")), from_id=str(d.get("from")), to_id=str(d.get("to")),
            transition_type=str(d.get("transition_type", "progression")), requirements_json=json_or_empty(d.get("requirements")),
            evidence_claim_ids=cids, status=str(d.get("status", "fixture")),
            duration_delta_months=opt_int(d.get("duration_delta_months")), cost_delta=opt_int(d.get("cost_delta")),
            note=str(d.get("note", ""))
        ):+> off_nodes[str(d.get("to"))];
    }
    catalogue_errors[mode] = "";
    return "";
}

def ensure_catalogue(mode: str) -> str {
    # Lazy one-time load: a hash-identical snapshot is reused, never rebuilt per request.
    if mode not in ["demo", "real"] {
        return f"unknown catalogue mode '{mode}'";
    }
    m = mode;
    existing = [root -->[?:CatalogueSnapshot, mode == m]];
    if len(existing) > 0 and catalogue_errors.get(mode, "") == "" {
        return "";
    }
    return import_catalogue(mode);
}

walker CollectWalker {
    has mode: str;
    has view: CatalogueView;

    can start with Root entry {
        m = self.mode;
        visit [-->[?:CatalogueSnapshot, mode == m]];
    }

    can snap with CatalogueSnapshot entry {
        self.view.version = here.version;
        self.view.content_hash = here.content_hash;
        self.view.banner = here.banner;
        self.view.notes = here.notes;
        visit [-->[?:CareerGoal]];
        visit [-->[?:Qualification]];
        visit [-->[?:EvidenceClaim]];
        visit [-->[?:Institution]];
    }

    can qual with Qualification entry {
        self.view.qualifications[here.qual_id] = QualificationView(qual_id=here.qual_id, name=here.name);
    }

    can claim with EvidenceClaim entry {
        self.view.claims[here.claim_id] = ClaimView(
            claim_id=here.claim_id, subject=here.subject, status=here.status, source_title=here.source_title,
            source_url=here.source_url, excerpt=here.excerpt, checked_date=here.checked_date, applies_to=here.applies_to
        );
    }

    can goal with CareerGoal entry {
        self.view.goals[here.goal_id] = GoalView(goal_id=here.goal_id, name=here.name, min_award_level=here.min_award_level);
    }

    can inst with Institution entry {
        self.view.institutions[here.inst_id] = here.name;
        visit [->:Offers:->[?:CourseOffering]];
    }

    can off with CourseOffering entry {
        awards: list[str] = [];
        for q in [here ->:Awards:->[?:Qualification]] {
            awards.append(q.qual_id);
            self.view.qualifications[q.qual_id] = QualificationView(qual_id=q.qual_id, name=q.name);
        }
        goals: list[str] = [];
        for g in [here ->:SupportsGoal:->[?:CareerGoal]] {
            goals.append(g.goal_id);
        }
        for c in [here ->:SupportedBy:->[?:EvidenceClaim]] {
            self.view.claims[c.claim_id] = ClaimView(
                claim_id=c.claim_id, subject=c.subject, status=c.status, source_title=c.source_title,
                source_url=c.source_url, excerpt=c.excerpt, checked_date=c.checked_date, applies_to=c.applies_to
            );
        }
        items: list[CostItem] = [];
        for ci in here.cost_items {
            items.append(CostItem(item_id=ci.item_id, label=ci.label, kind=ci.kind, category=ci.category, amount=ci.amount, essential=ci.essential));
        }
        self.view.offerings[here.offering_id] = OfferingView(
            offering_id=here.offering_id, title=here.title, institution_id=here.institution_id,
            institution_name=self.view.institutions.get(here.institution_id, here.institution_id),
            campus=here.campus, district=here.district, delivery_mode=here.delivery_mode, intake=here.intake,
            award_level=here.award_level, duration_months=here.duration_months, is_entry=here.is_entry,
            entry_rule=here.entry_rule, cost_items=items, awards=awards, goals=goals, evidence_ids=list(here.evidence_ids)
        );
        for e in [edge here ->:ProgressesTo:->] {
            self.view.transitions[e.transition_id] = TransitionView(
                transition_id=e.transition_id, from_id=e.from_id, to_id=e.to_id, transition_type=e.transition_type,
                requirements=e.requirements_json, evidence_claim_ids=list(e.evidence_claim_ids), status=e.status,
                duration_delta_months=e.duration_delta_months, cost_delta=e.cost_delta, note=e.note
            );
        }
    }
}

def load_view(mode: str) -> CatalogueView {
    view = CatalogueView(mode=mode);
    _ = root spawn CollectWalker(mode=mode, view=view);
    return view;
}

# ---------------------------------------------------------------------------
# 6. Route search: one walker per branch, each with its own copied state
# ---------------------------------------------------------------------------

def event(events: list[DecisionEvent], kind: str, actor: str, message: str, node_id: str = "") {
    events.append(DecisionEvent(seq=len(events) + 1, kind=kind, actor=actor, message=message, node_id=node_id));
}

def titled(view: CatalogueView, offering_id: str) -> str {
    ov = view.offerings.get(offering_id);
    if ov is None {
        return offering_id;
    }
    return ov.title;
}

walker AncestorWalker {
    # Walks backwards from the goal along SupportsGoal and ProgressesTo to find
    # the offerings that can matter for this goal.
    has mode: str;
    has goal_id: str;
    has goal_found: bool = False;
    has seen: list[str] = [];
    has offerings: list[CourseOffering] = [];

    can start with Root entry {
        m = self.mode;
        visit [-->[?:CatalogueSnapshot, mode == m]];
    }

    can snap with CatalogueSnapshot entry {
        gid = self.goal_id;
        visit [-->[?:CareerGoal, goal_id == gid]];
    }

    can goal with CareerGoal entry {
        self.goal_found = True;
        visit [here <-:SupportsGoal:<-[?:CourseOffering]];
    }

    can off with CourseOffering entry {
        if here.offering_id in self.seen {
            return;
        }
        self.seen.append(here.offering_id);
        self.offerings.append(here);
        visit [here <-:ProgressesTo:<-[?:CourseOffering]];
    }
}

walker RouteWalker {
    has profile: StudentProfile;
    has view: CatalogueView;
    has goal_id: str;
    has mode: str;
    has max_steps: int;
    has budget: SearchBudget;
    has state: SearchState;
    has found: list[RawRoute] = [];
    has blocked: list[BlockedItem] = [];
    has events: list[DecisionEvent] = [];

    can at_offering with CourseOffering entry {
        oid = here.offering_id;
        if here.catalogue_mode != self.mode {
            return;
        }
        if oid in self.state.path {
            event(self.events, "cycle_skipped", "search", f"Skipped {titled(self.view, oid)}: it is already on this branch.", oid);
            return;
        }
        if self.budget.expanded >= self.budget.max_states {
            self.budget.truncated = True;
            if "state limit" not in self.budget.reasons {
                self.budget.reasons.append("state limit");
            }
            return;
        }
        self.budget.expanded += 1;
        if len(self.state.path) == 0 {
            rule = rule_from_json(here.entry_rule);
            if rule is not None {
                leaves: list[Leaf] = [];
                res = eval_expr(rule as RequirementExpr, self.profile, [], leaves);
                if res == "fail" {
                    ev_status = worst_evidence(claim_statuses(self.view, here.evidence_ids));
                    fs = leaves_to_findings(leaves, "Gatekeeper", oid, "", "entry:" + oid, here.evidence_ids, ev_status);
                    msg = f"Entry blocked at {here.title}: " + "; ".join([f.message for f in fs if f.result == "fail"]);
                    self.blocked.append(BlockedItem(blocked_id="entry:" + oid, offering_id=oid, transition_id="", path=[], message=msg, findings=fs));
                    event(self.events, "branch_blocked", "search", msg, oid);
                    return;
                }
            }
        }
        self.state.path.append(oid);
        ov = self.view.offerings.get(oid);
        if ov is not None {
            for q in ov.awards {
                if q not in self.state.awards {
                    self.state.awards.append(q);
                }
            }
        }
        sig = oid + "|" + ",".join(sorted(self.state.awards)) + "|" + ",".join(self.state.transitions);
        self.state.signatures.append(sig);
        gid = self.goal_id;
        if len([here ->:SupportsGoal:->[?:CareerGoal, goal_id == gid]]) > 0 {
            if len(self.found) < self.budget.max_candidates {
                self.found.append(RawRoute(offering_ids=list(self.state.path), transition_ids=list(self.state.transitions)));
                event(self.events, "goal_reached", "search", f"Goal reached via {titled(self.view, oid)} ({len(self.state.path)} step(s)).", oid);
            } else {
                self.budget.truncated = True;
                if "candidate limit" not in self.budget.reasons {
                    self.budget.reasons.append("candidate limit");
                }
            }
            return;
        }
        outs = sorted([here ->:ProgressesTo:->[?:CourseOffering]], key=lambda n: CourseOffering : n.offering_id);
        if len(self.state.path) >= self.max_steps {
            if len(outs) > 0 {
                self.budget.truncated = True;
                if "step limit" not in self.budget.reasons {
                    self.budget.reasons.append("step limit");
                }
            }
            return;
        }
        for nxt in outs {
            for e in [edge here ->:ProgressesTo:-> nxt] {
                if nxt.offering_id in self.state.path {
                    event(self.events, "cycle_skipped", "search", f"Skipped transition {e.transition_id}: it would revisit {titled(self.view, nxt.offering_id)}.", nxt.offering_id);
                    continue;
                }
                trule = rule_from_json(e.requirements_json);
                if trule is not None {
                    tleaves: list[Leaf] = [];
                    tres = eval_expr(trule as RequirementExpr, self.profile, list(self.state.awards), tleaves);
                    if tres == "fail" {
                        tev = worst_evidence(claim_statuses(self.view, list(e.evidence_claim_ids)));
                        tfs = leaves_to_findings(tleaves, "Gatekeeper", nxt.offering_id, "", e.transition_id, list(e.evidence_claim_ids), tev);
                        tmsg = f"Cannot continue from {here.title} to {nxt.title}: " + "; ".join([f.message for f in tfs if f.result == "fail"]);
                        self.blocked.append(BlockedItem(blocked_id=e.transition_id, offering_id=nxt.offering_id, transition_id=e.transition_id, path=list(self.state.path), message=tmsg, findings=tfs));
                        event(self.events, "branch_blocked", "search", tmsg, nxt.offering_id);
                        continue;
                    }
                }
                child = RouteWalker(
                    profile=self.profile, view=self.view, goal_id=self.goal_id, mode=self.mode, max_steps=self.max_steps,
                    budget=self.budget,
                    state=SearchState(
                        path=list(self.state.path), awards=list(self.state.awards),
                        transitions=list(self.state.transitions) + [e.transition_id], signatures=list(self.state.signatures)
                    )
                );
                event(self.events, "branch_explored", "search", f"Exploring {nxt.title} via {e.transition_id}.", nxt.offering_id);
                nxt spawn child;
                for f in child.found {
                    self.found.append(f);
                }
                for b in child.blocked {
                    self.blocked.append(b);
                }
                for ev in child.events {
                    event(self.events, ev.kind, ev.actor, ev.message, ev.node_id);
                }
            }
        }
    }
}

obj SearchOutcome {
    has routes: list[RawRoute] = [];
    has blocked: list[BlockedItem] = [];
    has events: list[DecisionEvent] = [];
    has relevant_ids: list[str] = [];
    has entry_ids: list[str] = [];
    has expanded: int = 0;
    has truncated: bool = False;
    has reasons: list[str] = [];
}

def run_search(view: CatalogueView, profile: StudentProfile, max_steps: int, max_states: int = 100, max_candidates: int = 20) -> SearchOutcome {
    out = SearchOutcome();
    anc = root spawn AncestorWalker(mode=view.mode, goal_id=profile.goal_id);
    if not anc.goal_found {
        event(out.events, "goal_missing", "search", f"Goal {profile.goal_id} is not in the {view.mode} catalogue.");
        return out;
    }
    for o in anc.offerings {
        out.relevant_ids.append(o.offering_id);
    }
    out.relevant_ids = sorted(out.relevant_ids);
    budget = SearchBudget(max_states=max_states, max_candidates=max_candidates);
    entries = sorted([o for o in anc.offerings if o.is_entry], key=lambda n: CourseOffering : n.offering_id);
    for eo in entries {
        out.entry_ids.append(eo.offering_id);
        w = RouteWalker(
            profile=profile, view=view, goal_id=profile.goal_id, mode=view.mode, max_steps=max_steps,
            budget=budget, state=SearchState()
        );
        eo spawn w;
        for r in w.found {
            out.routes.append(r);
        }
        for b in w.blocked {
            out.blocked.append(b);
        }
        for ev in w.events {
            event(out.events, ev.kind, ev.actor, ev.message, ev.node_id);
        }
    }
    out.expanded = budget.expanded;
    out.truncated = budget.truncated;
    out.reasons = list(budget.reasons);
    return out;
}

# ---------------------------------------------------------------------------
# 7. Money: integer LKR, one rounding point (travel scenario rounds down)
# ---------------------------------------------------------------------------

def scaled_amount(item: CostItem, travel_pct: int) -> int | None {
    if item.amount is None {
        return None;
    }
    amt = item.amount or 0;
    if item.category == "travel" and travel_pct != 0 {
        return (amt * (100 + travel_pct)) // 100;
    }
    return amt;
}

def compute_ledger(steps: list[PlanStep], p: StudentProfile, travel_pct: int, delay_months: int) -> LedgerResult {
    lr = LedgerResult();
    lr.assumptions = [
        "Living costs are assumed covered outside this education budget.",
        "Upfront costs are paid at the start of a step; the monthly contribution arrives at month end.",
        "Amounts are whole LKR; scenario percentages round down."
    ];
    complete = True;
    total_months = 0;
    for s in steps {
        if s.duration_months is None {
            complete = False;
            lr.unknown_items.append(f"{s.title}: duration unknown");
        } else {
            total_months += s.duration_months or 0;
        }
    }
    known_total = 0;
    for s in steps {
        for it in s.cost_items {
            amt = scaled_amount(it, travel_pct);
            if amt is None {
                if it.essential {
                    complete = False;
                    lr.unknown_items.append(f"{s.title}: {it.label} unknown");
                }
                continue;
            }
            if it.kind == "recurring" {
                if s.duration_months is None {
                    continue;
                }
                known_total += (amt or 0) * (s.duration_months or 0);
            } else {
                known_total += amt or 0;
            }
        }
    }
    lr.known_total = known_total;
    if s_all_known(steps) {
        lr.duration_months = total_months + delay_months;
    }
    if delay_months > 0 {
        lr.assumptions.append(f"A {delay_months}-month delay adds {delay_months} months and no course costs; the monthly contribution is not counted during the delay.");
    }
    if p.savings is None {
        complete = False;
        lr.unknown_items.append("Your savings are not provided");
    }
    if p.monthly_contribution is None {
        complete = False;
        lr.unknown_items.append("Your monthly contribution is not provided");
    }
    lr.complete = complete;
    if not complete {
        return lr;
    }
    balance = p.savings or 0;
    contribution = p.monthly_contribution or 0;
    min_balance = balance;
    max_gap = 0;
    for s in steps {
        dur = s.duration_months or 0;
        for k in range(dur) {
            if k == 0 {
                for it in s.cost_items {
                    if it.kind == "upfront" {
                        balance -= scaled_amount(it, travel_pct) or 0;
                    }
                }
                if balance < min_balance {
                    min_balance = balance;
                }
            }
            balance += contribution;
            rec = 0;
            for it in s.cost_items {
                if it.kind == "recurring" {
                    rec += scaled_amount(it, travel_pct) or 0;
                }
            }
            balance -= rec;
            if balance < min_balance {
                min_balance = balance;
            }
            if rec - contribution > max_gap {
                max_gap = rec - contribution;
            }
        }
    }
    lr.minimum_balance = min_balance;
    lr.extra_initial_cash = max(0, -min_balance);
    lr.max_recurring_gap = max_gap;
    return lr;
}

def s_all_known(steps: list[PlanStep]) -> bool {
    for s in steps {
        if s.duration_months is None {
            return False;
        }
    }
    return True;
}

# ---------------------------------------------------------------------------
# 8. Whole-route validation, status and ranking (deterministic code decides)
# ---------------------------------------------------------------------------

def fingerprint_of(raw: RawRoute) -> str {
    return ">".join(raw.offering_ids) + "|" + ",".join(raw.transition_ids);
}

def plan_id_of(raw: RawRoute) -> str {
    return "plan-" + hashlib.sha1(fingerprint_of(raw).encode("utf-8")).hexdigest()[:10];
}

def build_candidate(raw: RawRoute, view: CatalogueView, p: StudentProfile, travel_pct: int = 0, delay_months: int = 0) -> CandidatePlan {
    # Revalidates every step and transition, then the complete route, from scratch.
    steps: list[PlanStep] = [];
    future: list[str] = [];
    conditions: list[str] = [];
    unknown_found = False;
    hard_fail = False;
    ev_all: list[str] = [];
    for i in range(len(raw.offering_ids)) {
        oid = raw.offering_ids[i];
        ov = view.offerings[oid];
        via = "";
        via_type = "";
        leaves: list[Leaf] = [];
        res = "pass";
        claim_ids: list[str] = list(ov.evidence_ids);
        rule_text = ov.entry_rule;
        rule_id = "entry:" + oid;
        duration = ov.duration_months;
        items: list[CostItem] = [];
        for ci in ov.cost_items {
            items.append(CostItem(item_id=ci.item_id, label=ci.label, kind=ci.kind, category=ci.category, amount=ci.amount, essential=ci.essential));
        }
        if i > 0 {
            via = raw.transition_ids[i - 1];
            tv = view.transitions[via];
            via_type = tv.transition_type;
            rule_text = tv.requirements;
            rule_id = via;
            for cid in tv.evidence_claim_ids {
                if cid not in claim_ids {
                    claim_ids.append(cid);
                }
            }
            # An exemption or transfer changes cost or duration only when a mapped effect exists.
            if tv.duration_delta_months is not None and duration is not None {
                duration = max(0, (duration or 0) + (tv.duration_delta_months or 0));
            }
            if tv.cost_delta is not None {
                items.append(CostItem(item_id=via + "-ADJ", label="Transition adjustment", kind="upfront", category="adjustment", amount=tv.cost_delta, essential=False));
            }
            if tv.status in ["unreviewed", "stale", "rejected"] {
                unknown_found = True;
                conditions.append(f"Transition {via} ({tv.transition_type}) is {tv.status} and needs confirmation with the institution.");
            }
        }
        rule = rule_from_json(rule_text);
        if rule is not None {
            res = eval_expr(rule as RequirementExpr, p, list(future), leaves);
        }
        statuses = claim_statuses(view, claim_ids);
        ev_status = worst_evidence(statuses);
        for st in statuses {
            ev_all.append(st);
        }
        fs = leaves_to_findings(leaves, "Gatekeeper", oid, "", rule_id, claim_ids, ev_status);
        for lf in leaves {
            if lf.conditional {
                prev = titled(view, raw.offering_ids[i - 1]) if i > 0 else "an earlier step";
                conditions.append(f"{lf.required} is only available after completing {prev}.");
            }
        }
        if res == "fail" {
            hard_fail = True;
        } elif res == "unknown" {
            unknown_found = True;
        }
        steps.append(PlanStep(
            offering_id=oid, title=ov.title, institution_name=ov.institution_name, award_level=ov.award_level,
            delivery_mode=ov.delivery_mode, campus=ov.campus, duration_months=duration, via_transition_id=via, via_type=via_type,
            check_result=res, check_findings=fs, evidence_status=ev_status, evidence_ids=claim_ids, cost_items=items
        ));
        for q in ov.awards {
            if q not in future {
                future.append(q);
            }
        }
    }
    ledger = compute_ledger(steps, p, travel_pct, delay_months);
    ev_worst = worst_evidence(ev_all);
    if ev_worst in ["unreviewed", "stale", "rejected"] {
        unknown_found = True;
    }
    status = "feasible_under_stated_assumptions";
    reason = "Every step passes the stated rules and the cash flow covers the route.";
    actions: list[str] = [];
    if hard_fail {
        status = "not_feasible_under_current_inputs";
        reason = "A step fails a requirement under the stated profile.";
    } elif ledger.complete and (ledger.extra_initial_cash or 0) > 0 {
        status = "not_feasible_under_current_inputs";
        reason = f"Cash flow falls short: about LKR {ledger.extra_initial_cash} more is needed before starting.";
        actions.append(f"Arrange or save about LKR {ledger.extra_initial_cash} extra before the first step.");
    } elif unknown_found or not ledger.complete {
        status = "needs_confirmation";
        reason = "Some required information, cost or evidence is missing or unconfirmed.";
        for u in ledger.unknown_items {
            actions.append(f"Confirm: {u}.");
        }
    } elif len(steps) > 1 {
        status = "conditional";
        reason = "Feasible only if each earlier step is completed first.";
    }
    for c in conditions {
        if "needs confirmation" in c {
            actions.append(c);
        }
    }
    if len(steps) > 1 and status != "not_feasible_under_current_inputs" {
        actions.append("Complete each step and meet its stated requirement before starting the next.");
    }
    raw_kind = "direct" if len(steps) == 1 else "multi_step";
    return CandidatePlan(
        plan_id=plan_id_of(raw), fingerprint=fingerprint_of(raw), route_kind=raw_kind, steps=steps, status=status,
        status_reason=reason, ledger=ledger, evidence_status=ev_worst, conditions=conditions, next_actions=actions
    );
}

def status_group(c: CandidatePlan) -> int {
    return STATUS_ORDER.index(c.status);
}

def dominates(a: CandidatePlan, b: CandidatePlan) -> bool {
    if a.ledger.duration_months is None or b.ledger.duration_months is None {
        return False;
    }
    if not a.ledger.complete or not b.ledger.complete {
        return False;
    }
    ac = a.ledger.known_total;
    bc = b.ledger.known_total;
    ad = a.ledger.duration_months or 0;
    bd = b.ledger.duration_months or 0;
    return ac <= bc and ad <= bd and (ac < bc or ad < bd);
}

def sort_key(c: CandidatePlan) -> tuple {
    total = c.ledger.known_total if c.ledger.complete else 10 ** 12;
    dur = (c.ledger.duration_months or 10 ** 6) if c.ledger.duration_months is not None else 10 ** 6;
    ai = c.ai_rank if c.ai_rank >= 0 else 10 ** 6;
    return (status_group(c), 1 if c.dominated else 0, ai, total, dur, c.fingerprint);
}

def rank_plans(plans: list[CandidatePlan]) -> list[CandidatePlan] {
    for c in plans {
        c.dominated = False;
        for o in plans {
            if o.plan_id != c.plan_id and status_group(o) == status_group(c) and dominates(o, c) {
                c.dominated = True;
            }
        }
    }
    return sorted(plans, key=sort_key);
}

def select_shown(ranked: list[CandidatePlan]) -> list[CandidatePlan] {
    # Up to three plans. One slot is reserved for the best direct route so that the
    # direct-versus-multi-step comparison is always visible.
    shown = list(ranked[:MAX_SHOWN]);
    has_direct = False;
    for c in shown {
        if c.route_kind == "direct" {
            has_direct = True;
        }
    }
    if not has_direct and len(ranked) > MAX_SHOWN {
        for c in ranked {
            if c.route_kind == "direct" {
                shown = list(ranked[:MAX_SHOWN - 1]) + [c];
                break;
            }
        }
    }
    return shown;
}

# ---------------------------------------------------------------------------
# 9. The council of lens walkers (request-local findings, nothing written to nodes)
# ---------------------------------------------------------------------------

glob LENS_NAMES: list[str] = ["Aspiration", "Fiscal", "Gatekeeper", "Bridge"];
glob AWARD_RANK: list[str] = ["foundation", "diploma", "degree"];

def step_index(plan: CandidatePlan, offering_id: str) -> int {
    for i in range(len(plan.steps)) {
        if plan.steps[i].offering_id == offering_id {
            return i;
        }
    }
    return -1;
}

def award_rank(level: str) -> int {
    if level in AWARD_RANK {
        return AWARD_RANK.index(level);
    }
    return -1;
}

walker LensBase {
    # Shared traversal: Root -> CatalogueSnapshot -> Institution -> CourseOffering.
    # Each lens adds an ability on CourseOffering and reads `here`.
    has view: CatalogueView;
    has plans: list[CandidatePlan];
    has profile: StudentProfile;
    has mode: str;
    has findings: list[Finding] = [];

    can start with Root entry {
        m = self.mode;
        visit [-->[?:CatalogueSnapshot, mode == m]];
    }

    can snap with CatalogueSnapshot entry {
        visit [-->[?:Institution]];
    }

    can inst with Institution entry {
        visit [->:Offers:->[?:CourseOffering]];
    }
}

walker AspirationLens(LensBase) {
    can inspect with CourseOffering entry {
        gid = self.profile.goal_id;
        goal = self.view.goals.get(gid);
        goal_name = goal.name if goal is not None else gid;
        for plan in self.plans {
            i = step_index(plan, here.offering_id);
            if i < 0 {
                continue;
            }
            last = (i == len(plan.steps) - 1);
            if last {
                need = goal.min_award_level if goal is not None else "";
                if need != "" and award_rank(here.award_level) >= 0 and award_rank(here.award_level) < award_rank(need) {
                    self.findings.append(Finding(lens="Aspiration", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="goal_level", result="fail",
                        message=f"{here.title} awards a {here.award_level}, below the {need} the goal needs.", required=need, actual=here.award_level));
                } else {
                    self.findings.append(Finding(lens="Aspiration", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="goal_support", result="pass",
                        message=f"Final step supports the goal '{goal_name}'.", required=need, actual=here.award_level));
                }
            } else {
                self.findings.append(Finding(lens="Aspiration", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="stepping_stone", result="info",
                    message=f"Stepping stone toward '{goal_name}'.", actual=here.award_level));
            }
            pref = self.profile.study_mode;
            if pref is not None and pref != "any" and here.delivery_mode != "" and here.delivery_mode != pref {
                self.findings.append(Finding(lens="Aspiration", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="study_mode_fit", result="info",
                    message=f"Delivery is {here.delivery_mode}; you prefer {pref}.", required=pref, actual=here.delivery_mode));
            }
        }
    }
}

walker FiscalLens(LensBase) {
    can inspect with CourseOffering entry {
        for plan in self.plans {
            i = step_index(plan, here.offering_id);
            if i < 0 {
                continue;
            }
            step = plan.steps[i];
            unknown_here: list[str] = [];
            for it in step.cost_items {
                if it.amount is None and it.essential {
                    unknown_here.append(it.label);
                }
            }
            if len(unknown_here) > 0 {
                self.findings.append(Finding(lens="Fiscal", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="cost_unknown", result="unknown",
                    message="Unknown cost: " + ", ".join(unknown_here) + ". Not treated as free."));
            } else {
                up = 0;
                mo = 0;
                for it in step.cost_items {
                    if it.kind == "upfront" {
                        up += it.amount or 0;
                    } else {
                        mo += it.amount or 0;
                    }
                }
                self.findings.append(Finding(lens="Fiscal", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="step_costs", result="pass",
                    message=f"Upfront LKR {up}; monthly LKR {mo} for {step.duration_months or 0} month(s)."));
            }
            if i == len(plan.steps) - 1 {
                lg = plan.ledger;
                if not lg.complete {
                    self.findings.append(Finding(lens="Fiscal", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="cash_flow", result="unknown",
                        message="Cash flow cannot be confirmed: " + "; ".join(lg.unknown_items) + "."));
                } elif (lg.extra_initial_cash or 0) > 0 {
                    self.findings.append(Finding(lens="Fiscal", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="cash_flow", result="fail",
                        message=f"Needs about LKR {lg.extra_initial_cash} extra before starting (lowest balance LKR {lg.minimum_balance}).",
                        required="balance >= 0", actual=str(lg.minimum_balance)));
                } else {
                    self.findings.append(Finding(lens="Fiscal", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="cash_flow", result="pass",
                        message=f"Cash flow covers the route (lowest balance LKR {lg.minimum_balance}).", required="balance >= 0", actual=str(lg.minimum_balance)));
                }
            }
        }
    }
}

walker GatekeeperLens(LensBase) {
    can inspect with CourseOffering entry {
        for plan in self.plans {
            i = step_index(plan, here.offering_id);
            if i < 0 {
                continue;
            }
            step = plan.steps[i];
            if len(step.check_findings) == 0 {
                self.findings.append(Finding(lens="Gatekeeper", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="no_rule", result="info",
                    message="No entry requirement is stated for this step.", evidence_ids=step.evidence_ids, evidence_status=step.evidence_status));
            }
            for f in step.check_findings {
                self.findings.append(Finding(
                    lens="Gatekeeper", candidate_id=plan.plan_id, node_id=f.node_id, rule_id=f.rule_id, result=f.result, message=f.message,
                    data_field=f.data_field, required=f.required, actual=f.actual, evidence_ids=f.evidence_ids, evidence_status=f.evidence_status
                ));
            }
        }
    }
}

walker BridgeLens(LensBase) {
    # Deterministic form: proposes existing multi-step routes that repair a blocked or
    # unconfirmed direct route. The LLM only reorders these (see rank_with_bridge_ai).
    has proposals: list[str] = [];

    can inspect with CourseOffering entry {
        for plan in self.plans {
            i = step_index(plan, here.offering_id);
            if i < 0 or i != len(plan.steps) - 1 or plan.route_kind != "multi_step" {
                continue;
            }
            for d in self.plans {
                if d.route_kind == "direct" and d.status != "feasible_under_stated_assumptions" {
                    if plan.plan_id not in self.proposals {
                        self.proposals.append(plan.plan_id);
                    }
                    self.findings.append(Finding(lens="Bridge", candidate_id=plan.plan_id, node_id=here.offering_id, rule_id="repairs:" + d.plan_id, result="info",
                        message=f"Existing catalogue route that can stand in for '{d.steps[0].title}' ({d.status})."));
                }
            }
        }
    }
}

obj LensRun {
    has findings: list[Finding] = [];
    has bridge_proposals: list[str] = [];
}

def run_lenses(view: CatalogueView, plans: list[CandidatePlan], profile: StudentProfile) -> LensRun {
    out = LensRun();
    if len(plans) == 0 {
        return out;
    }
    a = root spawn AspirationLens(view=view, plans=plans, profile=profile, mode=view.mode);
    f = root spawn FiscalLens(view=view, plans=plans, profile=profile, mode=view.mode);
    g = root spawn GatekeeperLens(view=view, plans=plans, profile=profile, mode=view.mode);
    b = root spawn BridgeLens(view=view, plans=plans, profile=profile, mode=view.mode);
    for x in a.findings { out.findings.append(x); }
    for x in f.findings { out.findings.append(x); }
    for x in g.findings { out.findings.append(x); }
    for x in b.findings { out.findings.append(x); }
    out.bridge_proposals = list(b.proposals);
    for plan in plans {
        for ln in LENS_NAMES {
            present = False;
            for x in out.findings {
                if x.candidate_id == plan.plan_id and x.lens == ln {
                    present = True;
                }
            }
            if not present {
                out.findings.append(Finding(lens=ln, candidate_id=plan.plan_id, node_id="", rule_id="not_applicable", result="info", message="Not applicable: this lens has no finding for this route."));
            }
        }
    }
    return out;
}

# ---------------------------------------------------------------------------
# 10. Clarification: one deterministic shortlist, the LLM can only pick from it
# ---------------------------------------------------------------------------

def question_text(data_field: str, view: CatalogueView) -> str {
    if data_field == "can_relocate" {
        return "Could you relocate (or travel) to study at a campus if a programme requires it?";
    }
    if data_field == "savings" {
        return "How much (in LKR) do you have saved to pay upfront costs?";
    }
    if data_field == "monthly_contribution" {
        return "How much (in LKR) can you put towards costs each month?";
    }
    if data_field == "study_mode" {
        return "How would you prefer to study: remote, on campus, hybrid or any?";
    }
    if data_field == "stream" {
        return "Which A/L stream did you study?";
    }
    if data_field.startswith("qualification:") {
        qid = data_field[len("qualification:"):];
        q = view.qualifications.get(qid);
        qname = q.name if q is not None else qid;
        return f"Do you hold: {qname}?";
    }
    if data_field.startswith("subject:") {
        return f"What grade did you get in {data_field[len('subject:'):]}?";
    }
    return f"Please provide: {data_field}.";
}

def answer_type_of(data_field: str) -> str {
    if data_field == "can_relocate" or data_field.startswith("qualification:") {
        return "boolean";
    }
    if data_field == "savings" or data_field == "monthly_contribution" {
        return "number";
    }
    return "text";
}

def plan_settled_red(c: CandidatePlan) -> bool {
    # An answer cannot rescue a route that already fails for a known reason.
    for s in c.steps {
        if s.check_result == "fail" {
            return True;
        }
    }
    return c.ledger.complete and (c.ledger.extra_initial_cash or 0) > 0;
}

def candidate_questions(plans: list[CandidatePlan], p: StudentProfile, view: CatalogueView) -> list[Question] {
    affected: dict[str, list[str]] = {};
    severity: dict[str, int] = {};
    for c in plans {
        if plan_settled_red(c) {
            continue;
        }
        for s in c.steps {
            for f in s.check_findings {
                if f.result == "unknown" and f.data_field != "" {
                    if f.data_field not in affected {
                        affected[f.data_field] = [];
                    }
                    if c.plan_id not in affected[f.data_field] {
                        affected[f.data_field].append(c.plan_id);
                    }
                    severity[f.data_field] = 2;
                }
            }
        }
        if not c.ledger.complete {
            for fld in ["savings", "monthly_contribution"] {
                missing = (fld == "savings" and p.savings is None) or (fld == "monthly_contribution" and p.monthly_contribution is None);
                if missing {
                    if fld not in affected {
                        affected[fld] = [];
                    }
                    if c.plan_id not in affected[fld] {
                        affected[fld].append(c.plan_id);
                    }
                    if fld not in severity {
                        severity[fld] = 1;
                    }
                }
            }
        }
    }
    out: list[Question] = [];
    for fld in sorted(list(affected.keys())) {
        if fld in p.skipped_fields {
            continue;
        }
        n = len(affected[fld]);
        effort = 1 if answer_type_of(fld) == "boolean" else 2;
        util = 10 * n + 3 * severity.get(fld, 1) - effort;
        out.append(Question(
            question_id="q-" + fld, data_field=fld, text=question_text(fld, view), answer_type=answer_type_of(fld),
            candidates_affected=n, utility=util
        ));
    }
    return sorted(out, key=lambda q: Question : (-q.utility, q.data_field));
}

# ---------------------------------------------------------------------------
# 11. LLM planner (proposes), deterministic fallback (decides identically by table)
# ---------------------------------------------------------------------------

obj PlannerObservation {
    has searched_alternatives: bool = False;
    has direct_ids: list[str] = [];
    has alternative_ids: list[str] = [];
    has unevaluated_ids: list[str] = [];
    has plan_summaries: list[str] = [];
    has missing_fields: list[str] = [];
    has asked_fields: list[str] = [];
    has remaining_actions: int = 6;
    has allowed_actions: list[str] = [];
    has profile_summary: str = "";
    has direct_is_clean: bool = False;
}

obj PlannerChoice {
    has action: str;
    has data_field: str = "";
    has plan_ids: list[str] = [];
}

sem PlannerChoice.action = "Exactly one of: ask_student, search_alternatives, evaluate_candidates, finish.";
sem PlannerChoice.data_field = "Only for ask_student: one field name copied from the observation's missing_fields list. Empty otherwise.";
sem PlannerChoice.plan_ids = "Only for evaluate_candidates: plan ids copied from the observation. Empty otherwise.";

def choose_action_ai(obs: PlannerObservation) -> PlannerChoice by llm(temperature=0.0, max_output_retries=0);
sem choose_action_ai = "Pick the single next action for an education-pathway planning run. Use finish when a clean direct route already exists and nothing relevant is missing. Use search_alternatives when direct routes are blocked, unaffordable or unconfirmed and alternatives have not been searched. Use ask_student only for a field listed in missing_fields. Use evaluate_candidates for alternative plan ids that are not yet evaluated. Never invent plan ids or fields.";
sem choose_action_ai.obs = "The current observation. Only plan ids and field names that appear in it may be used.";

obj RunState {
    has plans: dict[str, CandidatePlan] = {};
    has blocked: list[BlockedItem] = [];
    has blocked_ids: list[str] = [];
    has events: list[DecisionEvent] = [];
    has searched_alt: bool = False;
    has direct_ids: list[str] = [];
    has evaluated: list[str] = [];
    has asked: list[str] = [];
    has question: Question | None = None;
    has expanded: int = 0;
    has truncated: bool = False;
    has reasons: list[str] = [];
    has actions: list[str] = [];
    has attempts: int = 0;
    has live_calls_ok: int = 0;
    has fallback_calls: int = 0;
    has fallback_reason: str = "";
    has started: float = 0.0;
}

def live_ai_available() -> bool {
    if os.environ.get("UNIPATH_DISABLE_AI", "") == "1" {
        return False;
    }
    for k in ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GOOGLE_API_KEY"] {
        if os.environ.get(k, "") != "" {
            return True;
        }
    }
    return False;
}

def merge_search(rs: RunState, view: CatalogueView, profile: StudentProfile, outcome: SearchOutcome, direct_only: bool) -> list[str] {
    new_ids: list[str] = [];
    for r in outcome.routes {
        c = build_candidate(r, view, profile);
        if c.plan_id not in rs.plans {
            rs.plans[c.plan_id] = c;
            new_ids.append(c.plan_id);
        }
    }
    for b in outcome.blocked {
        if b.blocked_id not in rs.blocked_ids {
            rs.blocked_ids.append(b.blocked_id);
            rs.blocked.append(b);
        }
    }
    for ev in outcome.events {
        seen_before = False;
        for old_ev in rs.events {
            if old_ev.kind == ev.kind and old_ev.message == ev.message {
                seen_before = True;
            }
        }
        if not seen_before {
            event(rs.events, ev.kind, ev.actor, ev.message, ev.node_id);
        }
    }
    rs.expanded += outcome.expanded;
    if not direct_only and outcome.truncated {
        rs.truncated = True;
        for rsn in outcome.reasons {
            if rsn not in rs.reasons {
                rs.reasons.append(rsn);
            }
        }
    }
    return new_ids;
}

def summarize_plan(c: CandidatePlan) -> str {
    total = str(c.ledger.known_total) if c.ledger.complete else "unknown";
    return f"{c.plan_id} | {c.route_kind} | {c.status} | steps={len(c.steps)} | total_lkr={total}";
}

def observe(rs: RunState, profile: StudentProfile, view: CatalogueView) -> PlannerObservation {
    plans = list(rs.plans.values());
    obs = PlannerObservation();
    obs.searched_alternatives = rs.searched_alt;
    obs.direct_ids = list(rs.direct_ids);
    for c in plans {
        obs.plan_summaries.append(summarize_plan(c));
        if c.plan_id not in rs.direct_ids {
            obs.alternative_ids.append(c.plan_id);
        }
        if c.plan_id not in rs.evaluated and c.plan_id not in rs.direct_ids {
            obs.unevaluated_ids.append(c.plan_id);
        }
    }
    qs = candidate_questions(plans, profile, view);
    for q in qs {
        if q.data_field not in rs.asked {
            obs.missing_fields.append(q.data_field);
        }
    }
    obs.asked_fields = list(rs.asked);
    obs.remaining_actions = MAX_PLANNER_ACTIONS - len(rs.actions);
    obs.allowed_actions = list(PLANNER_ACTIONS);
    obs.profile_summary = f"goal={profile.goal_id}; savings_known={profile.savings is not None}; contribution_known={profile.monthly_contribution is not None}; relocation_known={profile.can_relocate is not None}; inventory_complete={profile.inventory_complete}";
    # Finish early only when every direct route is clean, so a failing or unaffordable
    # direct route always triggers a look at alternatives.
    clean = len(rs.direct_ids) > 0;
    for cid in rs.direct_ids {
        dc = rs.plans.get(cid);
        if dc is None or dc.status != "feasible_under_stated_assumptions" {
            clean = False;
        }
    }
    direct_missing = False;
    for q in candidate_questions([rs.plans[i] for i in rs.direct_ids if i in rs.plans], profile, view) {
        if q.data_field not in rs.asked {
            direct_missing = True;
        }
    }
    obs.direct_is_clean = clean and not direct_missing;
    return obs;
}

def rules_choice(obs: PlannerObservation) -> PlannerChoice {
    # The decision table from docs/architecture.md section 9.
    if obs.direct_is_clean {
        return PlannerChoice(action="finish");
    }
    if not obs.searched_alternatives {
        return PlannerChoice(action="search_alternatives");
    }
    if len(obs.missing_fields) > 0 {
        return PlannerChoice(action="ask_student", data_field=obs.missing_fields[0]);
    }
    if len(obs.unevaluated_ids) > 0 {
        return PlannerChoice(action="evaluate_candidates", plan_ids=list(obs.unevaluated_ids));
    }
    return PlannerChoice(action="finish");
}

def validate_choice(ch: PlannerChoice, obs: PlannerObservation) -> str {
    if ch.action not in PLANNER_ACTIONS {
        return f"unknown action '{ch.action}'";
    }
    if ch.action == "ask_student" {
        if ch.data_field not in obs.missing_fields {
            return f"invented question field '{ch.data_field}'";
        }
    }
    if ch.action == "search_alternatives" and obs.searched_alternatives {
        return "repeated identical search";
    }
    if ch.action == "evaluate_candidates" {
        if len(ch.plan_ids) == 0 {
            return "evaluate_candidates needs plan ids";
        }
        for pid in ch.plan_ids {
            if pid not in obs.alternative_ids and pid not in obs.direct_ids {
                return f"plan id '{pid}' was not issued in this run";
            }
        }
    }
    return "";
}

def call_with_timeout(fn: Callable[[PlannerObservation], PlannerChoice], obs: PlannerObservation, seconds: int) -> PlannerChoice {
    ex = ThreadPoolExecutor(max_workers=1);
    fut = ex.submit(fn, obs);
    try {
        res = fut.result(timeout=seconds);
    } finally {
        ex.shutdown(wait=False);
    }
    return res as PlannerChoice;
}

def next_choice(rs: RunState, obs: PlannerObservation, live: bool, chooser: Callable[[PlannerObservation], PlannerChoice] | None) -> PlannerChoice {
    # Returns the live model's validated choice, or the rules-table choice with a recorded reason.
    if not live {
        rs.fallback_calls += 1;
        if rs.fallback_reason == "" {
            rs.fallback_reason = "no_api_key";
        }
        return rules_choice(obs);
    }
    if rs.attempts >= MAX_PROVIDER_ATTEMPTS {
        rs.fallback_calls += 1;
        rs.fallback_reason = "provider_attempt_budget_spent";
        event(rs.events, "fallback", "rules_fallback", "Provider attempt budget spent; using the rules table.");
        return rules_choice(obs);
    }
    if time.time() - rs.started > RUN_SECONDS {
        rs.fallback_calls += 1;
        rs.fallback_reason = "run_time_budget_spent";
        event(rs.events, "fallback", "rules_fallback", "Run time budget spent; using the rules table.");
        return rules_choice(obs);
    }
    rs.attempts += 1;
    fn = chooser if chooser is not None else choose_action_ai;
    try {
        ch = call_with_timeout(fn, obs, ATTEMPT_SECONDS);
        problem = validate_choice(ch, obs);
        if problem != "" {
            rs.fallback_calls += 1;
            rs.fallback_reason = "invalid_model_output";
            event(rs.events, "guard_rejected", "planner_ai", f"Rejected model proposal: {problem}.");
            return rules_choice(obs);
        }
        rs.live_calls_ok += 1;
        return ch;
    } except Exception as ex {
        rs.fallback_calls += 1;
        rs.fallback_reason = "provider_error";
        event(rs.events, "fallback", "rules_fallback", f"Provider call failed ({type(ex).__name__}); using the rules table.");
        return rules_choice(obs);
    }
}

def evaluate_ids(rs: RunState, ids: list[str]) {
    for pid in ids {
        if pid not in rs.evaluated {
            rs.evaluated.append(pid);
        }
    }
}

def planner_mode_of(rs: RunState, live_requested: bool) -> str {
    if not live_requested {
        return "rules_fallback";
    }
    if rs.live_calls_ok > 0 and rs.fallback_calls == 0 {
        return "live_ai";
    }
    if rs.live_calls_ok > 0 {
        return "mixed";
    }
    return "rules_fallback";
}

def run_planner(view: CatalogueView, profile: StudentProfile, chooser: Callable[[PlannerObservation], PlannerChoice] | None = None, force_live: bool = False, max_states: int = 100) -> RunState {
    rs = RunState();
    rs.started = time.time();
    live = force_live or live_ai_available();
    # Coordinator step (always): evaluate the direct routes.
    direct_outcome = run_search(view, profile, 1, max_states);
    direct_ids = merge_search(rs, view, profile, direct_outcome, True);
    rs.direct_ids = list(direct_ids);
    rs.actions.append("evaluate_direct_routes");
    event(rs.events, "action", "coordinator", f"Evaluated {len(direct_ids)} direct route(s).");
    while len(rs.actions) < MAX_PLANNER_ACTIONS + 1 {
        obs = observe(rs, profile, view);
        ch = next_choice(rs, obs, live, chooser);
        actor = "planner_ai" if (live and rs.fallback_calls == 0 and rs.live_calls_ok > 0) else "rules_fallback";
        if ch.action == "finish" {
            rs.actions.append("finish");
            event(rs.events, "action", actor, "Finish: building the authoritative result.");
            break;
        }
        if ch.action == "search_alternatives" {
            outcome = run_search(view, profile, DEFAULT_MAX_STEPS, max_states);
            new_ids = merge_search(rs, view, profile, outcome, False);
            rs.searched_alt = True;
            rs.actions.append("search_alternatives");
            event(rs.events, "action", actor, f"Searched alternatives: {len(new_ids)} new route(s) found, {len(outcome.blocked)} branch(es) blocked.");
            continue;
        }
        if ch.action == "evaluate_candidates" {
            evaluate_ids(rs, ch.plan_ids);
            rs.actions.append("evaluate_candidates");
            event(rs.events, "action", actor, f"Evaluated {len(ch.plan_ids)} alternative route(s) with the four lenses.");
            continue;
        }
        if ch.action == "ask_student" {
            qs = candidate_questions(list(rs.plans.values()), profile, view);
            for q in qs {
                if q.data_field == ch.data_field {
                    rs.question = q;
                }
            }
            rs.asked.append(ch.data_field);
            rs.actions.append("ask_student");
            event(rs.events, "action", actor, f"Asked the student: {ch.data_field}. The run pauses until the answer arrives.");
            break;
        }
    }
    return rs;
}

# ---------------------------------------------------------------------------
# 12. Bridge lens, AI form: reorders and explains only routes the catalogue produced
# ---------------------------------------------------------------------------

obj BridgeOption {
    has plan_id: str;
    has summary: str;
}

obj RouteNote {
    has plan_id: str;
    has text: str;
}

obj BridgeRanking {
    has ordered_plan_ids: list[str];
    has notes: list[RouteNote] = [];
}

sem BridgeRanking.ordered_plan_ids = "Plan ids from the supplied options, best repair first. Use only supplied ids, each at most once.";
sem BridgeRanking.notes = "One short plain-language note (max 240 characters) per chosen plan id, using only facts in the option summary.";

def rank_bridge_routes(blocked_summary: str, options: list[BridgeOption]) -> BridgeRanking by llm(temperature=0.0, max_output_retries=0);
sem rank_bridge_routes = "A student's direct route is blocked, unaffordable or unconfirmed. Rank the supplied existing catalogue routes by how well they repair it and explain each briefly. Never invent routes, ids, fees or eligibility.";
sem rank_bridge_routes.blocked_summary = "What is wrong with the direct route.";
sem rank_bridge_routes.options = "The only routes you may rank.";

def validate_ranking(options: list[BridgeOption], ranking: BridgeRanking) -> str {
    ids = [o.plan_id for o in options];
    if len(ranking.ordered_plan_ids) == 0 {
        return "empty ranking";
    }
    seen: list[str] = [];
    for pid in ranking.ordered_plan_ids {
        if pid not in ids {
            return f"unknown plan id '{pid}'";
        }
        if pid in seen {
            return f"duplicate plan id '{pid}'";
        }
        seen.append(pid);
    }
    for n in ranking.notes {
        if n.plan_id not in ids {
            return f"note for unknown plan id '{n.plan_id}'";
        }
        if len(n.text) > 280 {
            return "note too long";
        }
    }
    return "";
}

def apply_bridge_ranking(plans: list[CandidatePlan], options: list[BridgeOption], ranking: BridgeRanking) -> str {
    problem = validate_ranking(options, ranking);
    if problem != "" {
        return problem;
    }
    for c in plans {
        c.ai_rank = -1;
        c.ai_note = "";
        for i in range(len(ranking.ordered_plan_ids)) {
            if ranking.ordered_plan_ids[i] == c.plan_id {
                c.ai_rank = i;
            }
        }
        for n in ranking.notes {
            if n.plan_id == c.plan_id {
                c.ai_note = n.text;
            }
        }
    }
    return "";
}

def call_ranker_with_timeout(fn: Callable[[str, list[BridgeOption]], BridgeRanking], summary: str, options: list[BridgeOption], seconds: int) -> BridgeRanking {
    ex = ThreadPoolExecutor(max_workers=1);
    fut = ex.submit(fn, summary, options);
    try {
        res = fut.result(timeout=seconds);
    } finally {
        ex.shutdown(wait=False);
    }
    return res as BridgeRanking;
}

def try_bridge_ai(rs: RunState, ranked: list[CandidatePlan], proposals: list[str], live: bool, ranker: Callable[[str, list[BridgeOption]], BridgeRanking] | None) -> str {
    # Returns a short note for the response ("" when not used).
    if not live or len(proposals) < 2 {
        return "";
    }
    if rs.attempts >= MAX_PROVIDER_ATTEMPTS or time.time() - rs.started > RUN_SECONDS {
        event(rs.events, "fallback", "rules_fallback", "Bridge ranking skipped: provider budget spent; deterministic order kept.");
        return "Bridge order is deterministic (AI budget spent).";
    }
    options: list[BridgeOption] = [];
    for c in ranked {
        if c.plan_id in proposals {
            options.append(BridgeOption(plan_id=c.plan_id, summary=summarize_plan(c)));
        }
    }
    direct_summary = "; ".join([summarize_plan(c) for c in ranked if c.route_kind == "direct"]);
    rs.attempts += 1;
    fn = ranker if ranker is not None else rank_bridge_routes;
    try {
        ranking = call_ranker_with_timeout(fn, direct_summary, options, ATTEMPT_SECONDS);
        problem = apply_bridge_ranking(ranked, options, ranking);
        if problem != "" {
            event(rs.events, "guard_rejected", "planner_ai", f"Rejected Bridge ranking: {problem}.");
            return "Bridge order is deterministic (AI output rejected).";
        }
        rs.live_calls_ok += 1;
        event(rs.events, "action", "planner_ai", "Bridge lens: the model reordered and explained existing catalogue routes.");
        return "Bridge order and notes were written by the AI model from catalogue data; eligibility is still decided by rules.";
    } except Exception as ex {
        rs.fallback_calls += 1;
        event(rs.events, "fallback", "rules_fallback", f"Bridge ranking failed ({type(ex).__name__}); deterministic order kept.");
        return "Bridge order is deterministic (AI unavailable).";
    }
}

# ---------------------------------------------------------------------------
# 13. Response assembly and request validation
# ---------------------------------------------------------------------------

def profile_hash_of(p: StudentProfile) -> str {
    d: dict[str, any] = {
        "goal": p.goal_id, "quals": sorted(p.qualifications), "not_held": sorted(p.not_held), "complete": p.inventory_complete,
        "grades": p.subject_grades, "stream": p.stream, "savings": p.savings, "contribution": p.monthly_contribution,
        "district": p.district, "relocate": p.can_relocate, "mode": p.study_mode, "skipped": sorted(p.skipped_fields),
        "catalogue": p.catalogue_mode
    };
    return hashlib.sha256(json.dumps(d, sort_keys=True).encode("utf-8")).hexdigest()[:12];
}

def validate_profile(p: StudentProfile, conversation_id: str, revision: int) -> str {
    if len(conversation_id) > 64 or revision < 0 or revision > 1000000 {
        return "REQUEST_LIMIT_EXCEEDED|conversation id or revision out of range";
    }
    if len(p.qualifications) > 30 or len(p.not_held) > 30 or len(p.subject_grades) > 20 or len(p.skipped_fields) > 20 {
        return "REQUEST_LIMIT_EXCEEDED|too many list entries";
    }
    if p.catalogue_mode not in ["demo", "real"] {
        return "INVALID_PROFILE|unknown catalogue mode";
    }
    if p.goal_id == "" or len(p.goal_id) > 64 {
        return "INVALID_PROFILE|a goal is required";
    }
    for q in p.qualifications {
        if len(q) > 64 {
            return "INVALID_PROFILE|qualification id too long";
        }
    }
    for k in p.subject_grades.keys() {
        if len(k) > 64 or p.subject_grades[k] not in GRADE_ORDER {
            return "INVALID_PROFILE|subject grade must be one of A, B, C, S, W, F";
        }
    }
    for amt in [p.savings, p.monthly_contribution] {
        if amt is not None and ((amt or 0) < 0 or (amt or 0) > 100000000) {
            return "INVALID_PROFILE|amounts must be between 0 and 100,000,000 LKR";
        }
    }
    if p.study_mode is not None and p.study_mode not in ["any", "remote", "on_campus", "hybrid"] {
        return "INVALID_PROFILE|study mode must be any, remote, on_campus or hybrid";
    }
    for s in [p.stream, p.district] {
        if s is not None and len(s or "") > 64 {
            return "INVALID_PROFILE|text field too long";
        }
    }
    return "";
}

def error_response(conversation_id: str, revision: int, code: str, message: str) -> PlanResponse {
    r = PlanResponse(request_id=uuid.uuid4().hex[:12], conversation_id=conversation_id, profile_revision=revision);
    r.run_status = "error";
    r.error_code = code;
    r.error_message = message;
    return r;
}

def graph_states_of(view: CatalogueView, plans: list[CandidatePlan], blocked: list[BlockedItem]) -> list[GraphNodeState] {
    out: list[GraphNodeState] = [];
    names: dict[str, str] = {
        "feasible_under_stated_assumptions": "feasible", "conditional": "conditional",
        "needs_confirmation": "needs_confirmation", "not_feasible_under_current_inputs": "not_feasible"
    };
    for oid in sorted(list(view.offerings.keys())) {
        best = 99;
        pids: list[str] = [];
        for c in plans {
            if step_index(c, oid) >= 0 {
                pids.append(c.plan_id);
                if status_group(c) < best {
                    best = status_group(c);
                }
            }
        }
        if best < 99 {
            out.append(GraphNodeState(node_id=oid, state=names[STATUS_ORDER[best]], plan_ids=pids));
            continue;
        }
        is_blocked = False;
        for b in blocked {
            if b.offering_id == oid {
                is_blocked = True;
            }
        }
        out.append(GraphNodeState(node_id=oid, state="blocked" if is_blocked else "unreached", plan_ids=[]));
    }
    return out;
}

def assemble_response(view: CatalogueView, profile: StudentProfile, rs: RunState, conversation_id: str, revision: int, live: bool, bridge_ranker: Callable[[str, list[BridgeOption]], BridgeRanking] | None) -> PlanResponse {
    plans = list(rs.plans.values());
    lens = run_lenses(view, plans, profile);
    for p in plans {
        evaluate_ids(rs, [p.plan_id]);
    }
    event(rs.events, "lens", "lens", f"Four lens walkers evaluated {len(plans)} route(s).");
    ranked = rank_plans(plans);
    bridge_note = try_bridge_ai(rs, ranked, lens.bridge_proposals, live, bridge_ranker);
    if bridge_note != "" and "written by the AI" in bridge_note {
        ranked = rank_plans(plans);
    }
    shown = select_shown(ranked);
    r = PlanResponse(request_id=uuid.uuid4().hex[:12], conversation_id=conversation_id, profile_revision=revision);
    r.profile_hash = profile_hash_of(profile);
    r.catalogue_mode = view.mode;
    r.catalogue_version = view.version;
    r.catalogue_hash = view.content_hash;
    r.banner = view.banner;
    r.candidates = shown;
    r.blocked_candidates = list(rs.blocked);
    shown_ids = [c.plan_id for c in shown];
    for c in ranked {
        if c.plan_id not in shown_ids {
            titles = " > ".join([st.title for st in c.steps]);
            r.blocked_candidates.append(BlockedItem(
                blocked_id="plan:" + c.plan_id, offering_id=c.steps[len(c.steps) - 1].offering_id, transition_id="",
                path=[st.offering_id for st in c.steps], message=f"{titles}: {c.status_reason}"
            ));
        }
    }
    r.findings = lens.findings;
    r.graph_states = graph_states_of(view, plans, rs.blocked);
    r.search_truncated = rs.truncated;
    r.bridge_note = bridge_note;
    r.planner_mode = planner_mode_of(rs, live);
    r.fallback_reason = rs.fallback_reason if r.planner_mode != "live_ai" else "";
    r.action_sequence = list(rs.actions);
    if rs.question is not None {
        r.pending_question = rs.question;
        r.run_status = "needs_input";
    }
    for i in range(len(rs.events)) {
        rs.events[i].seq = i + 1;
    }
    r.decision_events = rs.events;
    if view.mode == "demo" {
        r.warnings.append(view.banner);
    }
    if view.notes != "" {
        r.warnings.append(view.notes);
    }
    if rs.truncated {
        r.warnings.append("Search limits were reached (" + ", ".join(rs.reasons) + "); some routes may not be shown.");
    }
    if len(plans) == 0 {
        r.warnings.append("No route reaches this goal under the stated inputs. See the excluded options for reasons.");
    }
    if len(plans) > len(shown) {
        r.warnings.append(f"Showing {len(shown)} of {len(plans)} routes found. The others are listed under excluded options with their reasons.");
    }
    r.metrics = {
        "elapsed_ms": int((time.time() - rs.started) * 1000), "expanded_states": rs.expanded, "provider_attempts": rs.attempts,
        "routes_found": len(plans), "routes_shown": len(shown), "blocked_branches": len(rs.blocked)
    };
    return r;
}

def do_plan(profile: StudentProfile, conversation_id: str, revision: int, chooser: Callable[[PlannerObservation], PlannerChoice] | None = None, bridge_ranker: Callable[[str, list[BridgeOption]], BridgeRanking] | None = None, force_live: bool = False, max_states: int = 100, expected_hash: str = "") -> PlanResponse {
    problem = validate_profile(profile, conversation_id, revision);
    if problem != "" {
        parts = problem.split("|");
        return error_response(conversation_id, revision, parts[0], parts[1]);
    }
    err = ensure_catalogue(profile.catalogue_mode);
    if err != "" {
        return error_response(conversation_id, revision, "INTERNAL_ERROR", "The catalogue is not available right now.");
    }
    view = load_view(profile.catalogue_mode);
    if expected_hash != "" and expected_hash != view.content_hash {
        return error_response(conversation_id, revision, "CATALOGUE_CHANGED", "The catalogue changed. Reload and run the plan again.");
    }
    if profile.goal_id not in view.goals {
        return error_response(conversation_id, revision, "INVALID_PROFILE", "Unknown goal for this catalogue.");
    }
    unknown_quals = [q for q in profile.qualifications if q not in view.qualifications];
    live = force_live or live_ai_available();
    rs = run_planner(view, profile, chooser, force_live, max_states);
    resp = assemble_response(view, profile, rs, conversation_id, revision, live, bridge_ranker);
    if len(unknown_quals) > 0 {
        resp.warnings.append("Some qualification ids are not in this catalogue and were ignored for matching: " + ", ".join(unknown_quals));
    }
    return resp;
}

# ---------------------------------------------------------------------------
# 14. Stress test: same engine, a copy of the inputs, the same catalogue snapshot
# ---------------------------------------------------------------------------

glob SCENARIOS: dict[str, str] = {
    "travel_plus_40": "Travel +40%",
    "delay_6_months": "6-month delay"
};

def scenario_assumptions(scenario: str) -> list[str] {
    if scenario == "travel_plus_40" {
        return [
            "Only cost items categorised as travel increase by 40%, rounded down to whole LKR.",
            "Routes with no travel cost item show a zero delta. Unknown travel stays unknown.",
            "No other price, intake or income change is assumed."
        ];
    }
    return [
        "The start of the first step moves 6 months later, so total duration increases by 6 months.",
        "No course costs fall in the delay and your monthly contribution is NOT counted during it (conservative).",
        "Intake availability, inflation and new fees are not inferred."
    ];
}

def do_stress(profile: StudentProfile, scenario: str, conversation_id: str, revision: int) -> StressResponse {
    sr = StressResponse(request_id=uuid.uuid4().hex[:12], conversation_id=conversation_id, profile_revision=revision, scenario=scenario);
    if scenario not in SCENARIOS {
        sr.run_status = "error";
        sr.error_code = "INVALID_PROFILE";
        sr.error_message = "Unknown scenario.";
        return sr;
    }
    problem = validate_profile(profile, conversation_id, revision);
    if problem != "" {
        parts = problem.split("|");
        sr.run_status = "error";
        sr.error_code = parts[0];
        sr.error_message = parts[1];
        return sr;
    }
    err = ensure_catalogue(profile.catalogue_mode);
    if err != "" {
        sr.run_status = "error";
        sr.error_code = "INTERNAL_ERROR";
        sr.error_message = "The catalogue is not available right now.";
        return sr;
    }
    view = load_view(profile.catalogue_mode);
    if profile.goal_id not in view.goals {
        sr.run_status = "error";
        sr.error_code = "INVALID_PROFILE";
        sr.error_message = "Unknown goal for this catalogue.";
        return sr;
    }
    outcome = run_search(view, profile, DEFAULT_MAX_STEPS);
    travel_pct = 40 if scenario == "travel_plus_40" else 0;
    delay = 6 if scenario == "delay_6_months" else 0;
    base: list[CandidatePlan] = [];
    scen: list[CandidatePlan] = [];
    for rt in outcome.routes {
        base.append(build_candidate(rt, view, profile));
        scen.append(build_candidate(rt, view, profile, travel_pct, delay));
    }
    sr.assumptions = scenario_assumptions(scenario);
    for i in range(len(base)) {
        b = base[i];
        s = scen[i];
        d = PlanDelta(plan_id=b.plan_id, title=" > ".join([x.title for x in b.steps]), baseline_status=b.status, scenario_status=s.status);
        if b.ledger.complete and s.ledger.complete {
            d.cost_delta = s.ledger.known_total - b.ledger.known_total;
            d.shortfall_delta = (s.ledger.extra_initial_cash or 0) - (b.ledger.extra_initial_cash or 0);
        } else {
            d.note = "Some inputs are unknown, so cost and shortfall deltas are not shown.";
        }
        if b.ledger.duration_months is not None and s.ledger.duration_months is not None {
            d.duration_delta = (s.ledger.duration_months or 0) - (b.ledger.duration_months or 0);
        }
        sr.deltas.append(d);
    }
    sr.baseline = rank_plans(base);
    sr.scenario_plans = rank_plans(scen);
    return sr;
}

# ---------------------------------------------------------------------------
# 15. Public API (six operations)
# ---------------------------------------------------------------------------

def bad_input(msg: str) {
    raise ValueError("INVALID_PROFILE|" + msg);
}

def dict_str_list(v: any, label: str) -> list[str] {
    out: list[str] = [];
    if v is None {
        return out;
    }
    if not isinstance(v, list) {
        bad_input(f"{label} must be a list");
    }
    for x in (v as list[any]) {
        if not isinstance(x, str) {
            bad_input(f"{label} must contain text only");
        }
        out.append(x as str);
    }
    return out;
}

def dict_opt_int(v: any, label: str) -> int | None {
    if v is None {
        return None;
    }
    if isinstance(v, bool) or not isinstance(v, (int, float)) {
        bad_input(f"{label} must be a whole number");
    }
    return int(v as float);
}

def dict_opt_str(v: any, label: str) -> str | None {
    if v is None or v == "" {
        return None;
    }
    if not isinstance(v, str) {
        bad_input(f"{label} must be text");
    }
    return v as str;
}

def profile_from_dict(d: dict[str, any]) -> StudentProfile {
    # The browser sends plain JSON; every field is type-checked here before the profile is used.
    p = StudentProfile();
    gid = d.get("goal_id", "");
    if not isinstance(gid, str) {
        bad_input("goal_id must be text");
    }
    p.goal_id = gid as str;
    p.qualifications = dict_str_list(d.get("qualifications"), "qualifications");
    p.skipped_fields = dict_str_list(d.get("skipped_fields"), "skipped_fields");
    p.not_held = dict_str_list(d.get("not_held"), "not_held");
    p.inventory_complete = bool(d.get("inventory_complete", False));
    grades = d.get("subject_grades");
    if grades is not None {
        if not isinstance(grades, dict) {
            bad_input("subject_grades must be an object");
        }
        for k in (grades as dict[str, any]).keys() {
            gv = (grades as dict[str, any])[k];
            if not isinstance(gv, str) {
                bad_input("subject_grades must map subjects to grade letters");
            }
            p.subject_grades[str(k)] = gv as str;
        }
    }
    p.stream = dict_opt_str(d.get("stream"), "stream");
    p.district = dict_opt_str(d.get("district"), "district");
    p.study_mode = dict_opt_str(d.get("study_mode"), "study_mode");
    p.savings = dict_opt_int(d.get("savings"), "savings");
    p.monthly_contribution = dict_opt_int(d.get("monthly_contribution"), "monthly_contribution");
    rel = d.get("can_relocate");
    if rel is not None {
        if not isinstance(rel, bool) {
            bad_input("can_relocate must be true, false or empty");
        }
        p.can_relocate = rel as bool;
    }
    mode = d.get("catalogue_mode", "demo");
    if not isinstance(mode, str) {
        bad_input("catalogue_mode must be text");
    }
    p.catalogue_mode = mode as str;
    return p;
}

def profile_to_dict(p: StudentProfile) -> dict[str, any] {
    return {
        "goal_id": p.goal_id, "qualifications": list(p.qualifications), "not_held": list(p.not_held), "inventory_complete": p.inventory_complete,
        "subject_grades": dict(p.subject_grades), "stream": p.stream, "savings": p.savings,
        "monthly_contribution": p.monthly_contribution, "district": p.district, "can_relocate": p.can_relocate,
        "study_mode": p.study_mode, "skipped_fields": list(p.skipped_fields), "catalogue_mode": p.catalogue_mode
    };
}

def log_error(where: str, ex: Exception) {
    # Class and message only: never the profile or any student data.
    print(f"[unipath] {where} failed: {type(ex).__name__}: {str(ex)[:300]}");
}

def:pub get_app_info() -> AppInfo {
    info = AppInfo();
    info.catalogue_modes = ["demo", "real"];
    info.live_ai_available = live_ai_available();
    err = ensure_catalogue("demo");
    if err == "" {
        info.banner = load_view("demo").banner;
    }
    info.feature_flags = {"stress_test": True, "real_catalogue_reviewed": False, "live_planner": live_ai_available()};
    info.limits = {
        "max_steps": DEFAULT_MAX_STEPS, "max_states": DEFAULT_MAX_STATES, "max_candidates": DEFAULT_MAX_CANDIDATES,
        "max_shown": MAX_SHOWN, "max_provider_attempts": MAX_PROVIDER_ATTEMPTS, "attempt_seconds": ATTEMPT_SECONDS, "run_seconds": RUN_SECONDS
    };
    return info;
}

def:pub health() -> HealthInfo {
    h = HealthInfo();
    h.live_ai_available = live_ai_available();
    for m in ["demo", "real"] {
        err = ensure_catalogue(m);
        h.catalogue_ok[m] = (err == "");
    }
    h.ready = h.catalogue_ok.get("demo", False);
    h.detail = "ready" if h.ready else "demo catalogue failed to load: " + catalogue_errors.get("demo", "unknown error");
    return h;
}

def dfs_mark(u: str, adj: dict[str, list[str]], state: dict[str, int], back: list[str]) {
    state[u] = 1;
    for v in adj.get(u, []) {
        sv = state.get(v, 0);
        if sv == 1 {
            back.append(u + ">" + v);
        } elif sv == 0 {
            dfs_mark(v, adj, state, back);
        }
    }
    state[u] = 2;
}

def layer_offerings(view: CatalogueView) -> dict[str, int] {
    # Layered layout for the graph view: back-edges (cycles) are ignored, then each node
    # sits one layer after its deepest predecessor.
    adj: dict[str, list[str]] = {};
    for tid in sorted(list(view.transitions.keys())) {
        tv = view.transitions[tid];
        if tv.from_id not in adj {
            adj[tv.from_id] = [];
        }
        adj[tv.from_id].append(tv.to_id);
    }
    state: dict[str, int] = {};
    back: list[str] = [];
    entries = sorted([oid for oid in view.offerings.keys() if view.offerings[oid].is_entry]);
    for e in entries {
        if state.get(e, 0) == 0 {
            dfs_mark(e, adj, state, back);
        }
    }
    for oid in sorted(list(view.offerings.keys())) {
        if state.get(oid, 0) == 0 {
            dfs_mark(oid, adj, state, back);
        }
    }
    layer: dict[str, int] = {};
    for oid in view.offerings.keys() {
        layer[oid] = 0;
    }
    n = len(view.offerings);
    for _ in range(n + 1) {
        changed = False;
        for tid in sorted(list(view.transitions.keys())) {
            tv = view.transitions[tid];
            if (tv.from_id + ">" + tv.to_id) in back {
                continue;
            }
            if layer[tv.to_id] < layer[tv.from_id] + 1 {
                layer[tv.to_id] = layer[tv.from_id] + 1;
                changed = True;
            }
        }
        if not changed {
            break;
        }
    }
    return layer;
}

def:pub get_catalogue_projection(mode: str = "demo") -> Projection {
    if mode not in ["demo", "real"] or ensure_catalogue(mode) != "" {
        return Projection(mode=mode, banner="Catalogue unavailable");
    }
    view = load_view(mode);
    proj = Projection(mode=mode, version=view.version, banner=view.banner);
    for iid in sorted(list(view.institutions.keys())) {
        proj.nodes.append(ProjNode(node_id=iid, label=view.institutions[iid], kind="institution"));
    }

    for qid in sorted(list(view.qualifications.keys())) {
        proj.nodes.append(ProjNode(node_id=qid, label=view.qualifications[qid].name, kind="qualification"));
    }
    layers = layer_offerings(view);
    rows: dict[int, int] = {};
    max_layer = 0;
    for oid in sorted(list(view.offerings.keys())) {
        ov = view.offerings[oid];
        detail = f"{ov.award_level}, {ov.delivery_mode}, {ov.duration_months or 0} month(s)";
        ly = layers.get(oid, 0);
        rw = rows.get(ly, 0);
        rows[ly] = rw + 1;
        if ly > max_layer {
            max_layer = ly;
        }
        proj.nodes.append(ProjNode(node_id=oid, label=ov.title, kind="offering", detail=detail, is_entry=ov.is_entry, evidence_status=worst_evidence(claim_statuses(view, ov.evidence_ids)), layer=ly, row=rw));
        proj.edges.append(ProjEdge(edge_id="offers:" + oid, source=ov.institution_id, target=oid, kind="offers"));
        for q in ov.awards {
            proj.edges.append(ProjEdge(edge_id="awards:" + oid + ":" + q, source=oid, target=q, kind="awards"));
        }
        for g in ov.goals {
            proj.edges.append(ProjEdge(edge_id="goal:" + oid + ":" + g, source=oid, target=g, kind="supports_goal"));
        }
    }
    grow = 0;
    for gid in sorted(list(view.goals.keys())) {
        proj.nodes.append(ProjNode(node_id=gid, label=view.goals[gid].name, kind="goal", layer=max_layer + 1, row=grow));
        grow += 1;
    }
    for tid in sorted(list(view.transitions.keys())) {
        tv = view.transitions[tid];
        proj.edges.append(ProjEdge(edge_id=tid, source=tv.from_id, target=tv.to_id, kind="progresses_to", label=tv.transition_type, status=tv.status));
    }
    return proj;
}

def:pub get_evidence(claim_id: str, mode: str = "demo") -> EvidenceRecord {
    rec = EvidenceRecord(claim_id=claim_id);
    if mode not in ["demo", "real"] or len(claim_id) > 64 or ensure_catalogue(mode) != "" {
        return rec;
    }
    view = load_view(mode);
    c = view.claims.get(claim_id);
    if c is None {
        return rec;
    }
    rec.found = True;
    rec.subject = c.subject;
    rec.status = c.status;
    rec.source_title = c.source_title;
    rec.source_url = c.source_url;
    rec.excerpt = c.excerpt;
    rec.checked_date = c.checked_date;
    rec.applies_to = c.applies_to;
    return rec;
}

def:pub plan_pathways(profile: dict[str, any], conversation_id: str, profile_revision: int, expected_catalogue_hash: str = "") -> PlanResponse {
    try {
        parsed = profile_from_dict(profile);
        return do_plan(parsed, conversation_id, profile_revision, None, None, False, 100, expected_catalogue_hash);
    } except ValueError as ve {
        parts = str(ve).split("|");
        if len(parts) == 2 {
            return error_response(conversation_id, profile_revision, parts[0], parts[1]);
        }
        log_error("plan_pathways", ve);
        return error_response(conversation_id, profile_revision, "INVALID_PROFILE", "The profile could not be read.");
    } except Exception as ex {
        log_error("plan_pathways", ex);
        return error_response(conversation_id, profile_revision, "INTERNAL_ERROR", "Something went wrong while planning. Please try again.");
    }
}

def:pub run_stress_test(profile: dict[str, any], scenario: str, conversation_id: str, profile_revision: int) -> StressResponse {
    try {
        parsed = profile_from_dict(profile);
        return do_stress(parsed, scenario, conversation_id, profile_revision);
    } except ValueError as ve {
        parts = str(ve).split("|");
        sr0 = StressResponse(request_id=uuid.uuid4().hex[:12], conversation_id=conversation_id, profile_revision=profile_revision, scenario=scenario);
        sr0.run_status = "error";
        sr0.error_code = parts[0] if len(parts) == 2 else "INVALID_PROFILE";
        sr0.error_message = parts[1] if len(parts) == 2 else "The profile could not be read.";
        return sr0;
    } except Exception as ex {
        log_error("run_stress_test", ex);
        sr = StressResponse(request_id=uuid.uuid4().hex[:12], conversation_id=conversation_id, profile_revision=profile_revision, scenario=scenario);
        sr.run_status = "error";
        sr.error_code = "INTERNAL_ERROR";
        sr.error_message = "Something went wrong while running the stress test.";
        return sr;
    }
}
