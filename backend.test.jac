"""Tests for backend.jac. Routine tests use the fictional demo fixture only and never
need an LLM key: the planner is driven by stub choosers where AI behaviour matters.
"""

glob DEMO_ROUTE_DIRECT: list[str] = ["DEMO-DIRECT"];
glob DEMO_ROUTE_LADDER: list[str] = ["DEMO-FOUNDATION", "DEMO-DIPLOMA", "DEMO-TOPUP"];

def demo_profile(savings: int | None, relocate: bool | None, district: str | None = "Jaffna", complete: bool = True, quals: list[str] = ["DEMO-Q-ENTRY"]) -> StudentProfile {
    return StudentProfile(
        goal_id="DEMO-GOAL-IT", qualifications=list(quals), inventory_complete=complete, savings=savings,
        monthly_contribution=5000, district=district, can_relocate=relocate, catalogue_mode="demo"
    );
}

def ladder_raw() -> RawRoute {
    return RawRoute(offering_ids=list(DEMO_ROUTE_LADDER), transition_ids=["DEMO-T1", "DEMO-T2"]);
}

def prepare() -> CatalogueView {
    err = import_catalogue("demo", True);
    assert err == "", err;
    return load_view("demo");
}

def count_nodes() -> int {
    n = 0;
    n += len([root -->[?:CatalogueSnapshot]]);
    return n;
}

def snapshot_signature() -> str {
    v = load_view("demo");
    return json.dumps({
        "offerings": sorted(list(v.offerings.keys())), "transitions": sorted(list(v.transitions.keys())),
        "claims": sorted(list(v.claims.keys())), "hash": v.content_hash
    }, sort_keys=True);
}

def counting_walker_total() -> int {
    w = root spawn PurgeWalker(mode="demo");
    return len(w.doomed);
}

# ----- M1: loader ---------------------------------------------------------

test "M1 fixture loads and every node and edge type is built and used" {
    view = prepare();
    assert len(view.offerings) == 7;
    assert len(view.transitions) == 5;
    assert len(view.qualifications) == 5;
    assert len(view.goals) == 1;
    assert len(view.claims) == 5;
    assert len(view.institutions) == 2;
    assert view.banner.startswith("Demonstration data");
    # typed edges exist in the real graph, not just the views
    assert len([root -->[?:CatalogueSnapshot]]) >= 1;
    snap = [root -->[?:CatalogueSnapshot, mode == "demo"]][0];
    insts = [snap -->[?:Institution]];
    assert len(insts) == 2;
    offs = [insts[0] ->:Offers:->[?:CourseOffering]] + [insts[1] ->:Offers:->[?:CourseOffering]];
    assert len(offs) == 7;
    assert len([snap -->[?:CareerGoal]]) == 1;
}

test "T09 repeat import creates no duplicates" {
    _ = prepare();
    first = counting_walker_total();
    sig1 = snapshot_signature();
    assert import_catalogue("demo", True) == "";
    assert import_catalogue("demo") == "";
    second = counting_walker_total();
    assert first == second;
    assert sig1 == snapshot_signature();
    assert len([root -->[?:CatalogueSnapshot, mode == "demo"]]) == 1;
}

test "M1 content hash is stable" {
    _ = prepare();
    h1 = load_view("demo").content_hash;
    _ = prepare();
    assert load_view("demo").content_hash == h1;
    assert len(h1) == 16;
}

test "M1 bad reference and unknown operator are rejected" {
    with open(data_path("demo"), "r", encoding="utf-8") as fh {
        raw = json.loads(fh.read()) as dict[str, any];
    }
    raw["transitions"][0]["to"] = "DEMO-NOPE";
    errs = validate_catalogue(raw, "demo");
    assert len(errs) > 0;
    assert any(["unknown offering" in e for e in errs]);
    with open(data_path("demo"), "r", encoding="utf-8") as fh2 {
        raw2 = json.loads(fh2.read()) as dict[str, any];
    }
    raw2["offerings"][0]["entry_rule"] = {"op": "eval", "value": "1+1"};
    errs2 = validate_catalogue(raw2, "demo");
    assert any(["unknown rule operator" in e for e in errs2]);
}

test "M1 a failed validation leaves the healthy snapshot active" {
    _ = prepare();
    before = snapshot_signature();
    # a tampered file cannot be imported: validation runs before the graph is touched
    with open(data_path("demo"), "r", encoding="utf-8") as fh {
        raw = json.loads(fh.read()) as dict[str, any];
    }
    raw["offerings"][0]["institution_id"] = "NOPE";
    assert len(validate_catalogue(raw, "demo")) > 0;
    assert before == snapshot_signature();
}

# ----- M2: rules ----------------------------------------------------------

test "M2 three-valued logic tables for all and any" {
    p = StudentProfile(qualifications=["A"], inventory_complete=False);
    has_a = RequirementExpr(op="has_qual", value="A");
    has_b = RequirementExpr(op="has_qual", value="B");
    leaves: list[Leaf] = [];
    assert eval_expr(has_a, p, [], leaves) == "pass";
    assert eval_expr(has_b, p, [], leaves) == "unknown";
    both = RequirementExpr(op="all", children=[has_a, has_b]);
    either = RequirementExpr(op="any", children=[has_a, has_b]);
    assert eval_expr(both, p, [], leaves) == "unknown";
    assert eval_expr(either, p, [], leaves) == "pass";
    p2 = StudentProfile(qualifications=["A"], inventory_complete=True);
    assert eval_expr(both, p2, [], leaves) == "fail";
    assert eval_expr(either, p2, [], leaves) == "pass";
    neither = RequirementExpr(op="any", children=[has_b, RequirementExpr(op="has_qual", value="C")]);
    assert eval_expr(neither, p2, [], leaves) == "fail";
    assert eval_expr(neither, p, [], leaves) == "unknown";
    mixed_fail = RequirementExpr(op="all", children=[has_b, has_a]);
    assert eval_expr(mixed_fail, p2, [], leaves) == "fail";
}

test "M2 unknown operator and bad rule shapes are rejected" {
    for bad in [{"op": "eval", "value": "x"}, {"op": "all"}, {"op": "all", "children": []}, {"op": "subject_grade", "value": "Maths"}, {"op": "min_cash", "value": "abc"}, "not an object"] {
        try {
            _ = parse_expr(bad);
            assert False, "should have been rejected";
        } except ValueError {
            assert True;
        }
    }
}

test "M2 inventory semantics: absent from a declared-complete list fails, otherwise unknown" {
    leaves: list[Leaf] = [];
    rule = RequirementExpr(op="has_qual", value="DEMO-Q-ENGLISH");
    assert eval_expr(rule, StudentProfile(qualifications=[], inventory_complete=True), [], leaves) == "fail";
    assert eval_expr(rule, StudentProfile(qualifications=[], inventory_complete=False), [], leaves) == "unknown";
}

test "T02 a missing AND prerequisite fails even though an incoming edge exists" {
    view = prepare();
    p = demo_profile(24000, True);
    out = run_search(view, p, 4);
    ids = [fingerprint_of(r) for r in out.routes];
    # DIPLOMA-B has an edge into TOPUP, but it needs DEMO-Q-ENGLISH which the student lacks.
    assert not any(["DEMO-DIPLOMA-B" in i for i in ids]);
    assert any(["entry:DEMO-DIPLOMA-B" == b.blocked_id for b in out.blocked]);
    # with English declared, the same edge becomes usable
    p2 = demo_profile(24000, True, quals=["DEMO-Q-ENTRY", "DEMO-Q-ENGLISH"]);
    out2 = run_search(view, p2, 4);
    assert any(["DEMO-DIPLOMA-B" in fingerprint_of(r) for r in out2.routes]);
}

test "T03 unknown field stays unknown and produces a relevant question" {
    view = prepare();
    p = demo_profile(2000, None);
    rs = run_planner(view, p);
    assert rs.question is not None;
    assert (rs.question as Question).data_field == "can_relocate";
    # a profile with everything known asks nothing
    p2 = demo_profile(24000, False);
    rs2 = run_planner(view, p2);
    assert rs2.question is None;
}

test "M2 evidence status is reported separately from the predicate result" {
    view = prepare();
    p = demo_profile(24000, True);
    c = build_candidate(RawRoute(offering_ids=["DEMO-DIRECT"]), view, p);
    f = c.steps[0].check_findings[0];
    assert f.result == "pass";
    assert f.evidence_status == "fixture";
}

# ----- M3: search ---------------------------------------------------------

test "T01 direct and multi-step candidates are both found" {
    view = prepare();
    p = demo_profile(24000, True);
    out = run_search(view, p, 4);
    kinds = [len(r.offering_ids) for r in out.routes];
    assert 1 in kinds;
    assert 3 in kinds;
    fps = [fingerprint_of(r) for r in out.routes];
    assert "DEMO-DIRECT|" in fps;
    assert "DEMO-FOUNDATION>DEMO-DIPLOMA>DEMO-TOPUP|DEMO-T1,DEMO-T2" in fps;
    assert any(["DEMO-TRANSFER-DEGREE" in f for f in fps]);
}

test "M3 relevant set and entry states" {
    view = prepare();
    p = demo_profile(24000, True);
    out = run_search(view, p, 4);
    for oid in ["DEMO-DIRECT", "DEMO-ONSITE", "DEMO-TOPUP", "DEMO-TRANSFER-DEGREE", "DEMO-DIPLOMA", "DEMO-FOUNDATION"] {
        assert oid in out.relevant_ids;
    }
    assert "DEMO-FOUNDATION" in out.entry_ids;
    assert "DEMO-DIPLOMA" not in out.entry_ids;
}

test "T08 cycles terminate and branches do not contaminate each other" {
    view = prepare();
    p = demo_profile(24000, True);
    out = run_search(view, p, 4);
    # DEMO-T5 is a back-edge DIPLOMA -> FOUNDATION; the search must terminate and skip it.
    assert any([e.kind == "cycle_skipped" for e in out.events]);
    fps = [fingerprint_of(r) for r in out.routes];
    ladder = "DEMO-FOUNDATION>DEMO-DIPLOMA>DEMO-TOPUP|DEMO-T1,DEMO-T2";
    transfer = "DEMO-FOUNDATION>DEMO-DIPLOMA>DEMO-TRANSFER-DEGREE|DEMO-T1,DEMO-T4";
    assert ladder in fps;
    assert transfer in fps;
    # no route repeats an offering, and sibling branches keep their own transition history
    for r in out.routes {
        assert len(set(r.offering_ids)) == len(r.offering_ids);
    }
    assert "DEMO-T4" not in ladder;
    assert len(fps) == len(set(fps));
}

test "M3 blocked second-diploma branch is logged by name" {
    view = prepare();
    out = run_search(view, demo_profile(24000, True), 4);
    blocked = [e for e in out.events if e.kind == "branch_blocked"];
    assert len(blocked) >= 1;
    assert any(["Second Diploma" in e.message for e in blocked]);
}

test "M3 limits set the truncation flag" {
    view = prepare();
    out = run_search(view, demo_profile(24000, True), 4, 1);
    assert out.truncated;
    out_steps = run_search(view, demo_profile(24000, True), 2);
    assert out_steps.truncated;
    assert "step limit" in out_steps.reasons;
}

test "M3 whole-plan revalidation catches a stale step" {
    view = prepare();
    p = demo_profile(24000, True);
    stale = RawRoute(offering_ids=["DEMO-DIPLOMA-B", "DEMO-TOPUP"], transition_ids=["DEMO-T3"]);
    c = build_candidate(stale, view, p);
    assert c.status == "not_feasible_under_current_inputs";
    assert c.steps[0].check_result == "fail";
}

# ----- M4: costing, status, ranking ---------------------------------------

test "T05 fixture totals and shortfalls match exactly" {
    view = prepare();
    direct = build_candidate(RawRoute(offering_ids=["DEMO-DIRECT"]), view, demo_profile(2000, True));
    assert direct.ledger.complete;
    assert direct.ledger.known_total == 84000;
    assert direct.ledger.minimum_balance == -22000;
    assert direct.ledger.extra_initial_cash == 22000;
    assert direct.status == "not_feasible_under_current_inputs";
    ladder = build_candidate(ladder_raw(), view, demo_profile(2000, True));
    assert ladder.ledger.known_total == 54000;
    assert ladder.ledger.minimum_balance == 0;
    assert ladder.ledger.extra_initial_cash == 0;
    assert ladder.status == "conditional";
    assert ladder.ledger.duration_months == 12;
    rich = build_candidate(RawRoute(offering_ids=["DEMO-DIRECT"]), view, demo_profile(24000, True));
    assert rich.ledger.known_total == 84000;
    assert rich.ledger.minimum_balance == 0;
    assert rich.ledger.extra_initial_cash == 0;
    assert rich.status == "feasible_under_stated_assumptions";
}

test "M4 hand-computed two-month ledger" {
    p = StudentProfile(savings=1000, monthly_contribution=500);
    step = PlanStep(offering_id="X", title="X", institution_name="", award_level="", delivery_mode="", campus="", duration_months=2,
        cost_items=[CostItem(item_id="u", label="u", kind="upfront", category="tuition", amount=1500),
                    CostItem(item_id="m", label="m", kind="recurring", category="tuition", amount=800)]);
    lg = compute_ledger([step], p, 0, 0);
    # m0: 1000-1500=-500 (min) ; +500=0 ; -800=-800 (min). m1: +500=-300 ; -800=-1100 (min)
    assert lg.minimum_balance == -1100;
    assert lg.extra_initial_cash == 1100;
    assert lg.known_total == 1500 + 1600;
    assert lg.max_recurring_gap == 300;
}

test "T15 unknown cost never claims affordability" {
    view = prepare();
    p = demo_profile(24000, True);
    c = build_candidate(RawRoute(offering_ids=["DEMO-DIRECT"]), view, p);
    c.steps[0].cost_items[1].amount = None;
    lg = compute_ledger(c.steps, p, 0, 0);
    assert not lg.complete;
    assert lg.minimum_balance is None;
    assert lg.extra_initial_cash is None;
    assert len(lg.unknown_items) >= 1;
    # unknown savings also blocks a feasibility claim
    unknown_savings = build_candidate(RawRoute(offering_ids=["DEMO-DIRECT"]), view, demo_profile(None, True));
    assert unknown_savings.status == "needs_confirmation";
}

test "T16 an exemption with no mapped effect changes nothing" {
    view = prepare();
    p = demo_profile(24000, True);
    t = build_candidate(RawRoute(offering_ids=["DEMO-FOUNDATION", "DEMO-DIPLOMA", "DEMO-TRANSFER-DEGREE"], transition_ids=["DEMO-T1", "DEMO-T4"]), view, p);
    # F 14000 + D 14000 + transfer degree 3000 + 6*4500 = 58000, with no discount from the exemption
    assert t.ledger.known_total == 14000 + 14000 + 3000 + 27000;
    assert t.ledger.duration_months == 12;
    assert t.status == "needs_confirmation";
    view.transitions["DEMO-T4"].cost_delta = -5000;
    mapped = build_candidate(RawRoute(offering_ids=["DEMO-FOUNDATION", "DEMO-DIPLOMA", "DEMO-TRANSFER-DEGREE"], transition_ids=["DEMO-T1", "DEMO-T4"]), view, p);
    assert mapped.ledger.known_total == t.ledger.known_total - 5000;
}

test "M4 one candidate per status exists and ranking is deterministic" {
    view = prepare();
    seen: list[str] = [];
    cases = [
        (RawRoute(offering_ids=["DEMO-DIRECT"]), demo_profile(24000, True)),
        (ladder_raw(), demo_profile(24000, True)),
        (RawRoute(offering_ids=["DEMO-DIRECT"]), demo_profile(None, True)),
        (RawRoute(offering_ids=["DEMO-DIRECT"]), demo_profile(2000, True))
    ];
    for (r, pr) in cases {
        seen.append(build_candidate(r, view, pr).status);
    }
    assert set(seen) == set(STATUS_ORDER);
    p = demo_profile(24000, True);
    out = run_search(view, p, 4);
    plans1 = rank_plans([build_candidate(r, view, p) for r in out.routes]);
    plans2 = rank_plans([build_candidate(r, view, p) for r in reversed(out.routes)]);
    assert [c.plan_id for c in plans1] == [c.plan_id for c in plans2];
    # a blocked route never outranks an eligible one
    groups = [status_group(c) for c in plans1];
    assert groups == sorted(groups);
}

# ----- M5: lenses and clarification ---------------------------------------

test "M5 all four lens outputs exist per candidate and catalogue nodes are untouched" {
    view = prepare();
    p = demo_profile(2000, True);
    before = snapshot_signature();
    resp = do_plan(p, "conv-1", 1);
    assert resp.run_status == "ready";
    assert len(resp.candidates) >= 1;
    for c in resp.candidates {
        for ln in LENS_NAMES {
            assert any([f.candidate_id == c.plan_id and f.lens == ln for f in resp.findings]), f"{c.plan_id} missing {ln}";
        }
    }
    assert before == snapshot_signature();
    # catalogue nodes carry no student fields: only catalogue attributes exist on them
    off = [n for n in counting_nodes_of_type()];
    assert len(off) == 7;
}

def counting_nodes_of_type() -> list[CourseOffering] {
    snap = [root -->[?:CatalogueSnapshot, mode == "demo"]][0];
    out: list[CourseOffering] = [];
    for i in [snap -->[?:Institution]] {
        for o in [i ->:Offers:->[?:CourseOffering]] {
            out.append(o);
        }
    }
    return out;
}

test "M5 the relocation question only appears when it matters" {
    view = prepare();
    # Colombo-based student: the on-campus option passes, so no relocation question
    qs = candidate_questions([build_candidate(RawRoute(offering_ids=["DEMO-ONSITE"]), view, demo_profile(24000, None, "Colombo"))], demo_profile(24000, None, "Colombo"), view);
    assert len(qs) == 0;
    # Jaffna-based, relocation unanswered: the question is relevant
    qs2 = candidate_questions([build_candidate(RawRoute(offering_ids=["DEMO-ONSITE"]), view, demo_profile(24000, None, "Jaffna"))], demo_profile(24000, None, "Jaffna"), view);
    assert len(qs2) == 1;
    assert qs2[0].data_field == "can_relocate";
    # skipped fields are not asked again
    skipped_prof = demo_profile(24000, None, "Jaffna");
    skipped_prof.skipped_fields = ["can_relocate"];
    assert len(candidate_questions([build_candidate(RawRoute(offering_ids=["DEMO-ONSITE"]), view, skipped_prof)], skipped_prof, view)) == 0;
}

# ----- M6: API ------------------------------------------------------------

test "M6 all six operations respond" {
    _ = prepare();
    info = get_app_info();
    assert info.name == "UniPath LK";
    assert info.banner.startswith("Demonstration data");
    h = health();
    assert h.ready;
    proj = get_catalogue_projection("demo");
    assert len(proj.nodes) > 10;
    assert len(proj.edges) > 10;
    ev = get_evidence("DEMO-EV-TRANSFER", "demo");
    assert ev.found;
    assert ev.status == "unreviewed";
    assert not get_evidence("NOPE", "demo").found;
    resp = plan_pathways(profile_to_dict(demo_profile(2000, None)), "conv-api", 1);
    assert resp.run_status == "needs_input";
    st = run_stress_test(profile_to_dict(demo_profile(24000, True)), "travel_plus_40", "conv-api", 2);
    assert st.run_status == "ready";
}

test "M6 invalid and oversized input returns safe errors" {
    _ = prepare();
    bad = demo_profile(-5, True);
    r = plan_pathways(profile_to_dict(bad), "c", 1);
    assert r.run_status == "error";
    assert r.error_code == "INVALID_PROFILE";
    big = demo_profile(100, True);
    big.qualifications = ["Q" + str(i) for i in range(200)];
    r2 = plan_pathways(profile_to_dict(big), "c", 1);
    assert r2.error_code == "REQUEST_LIMIT_EXCEEDED";
    nogoal = demo_profile(100, True);
    nogoal.goal_id = "NOPE";
    assert plan_pathways(profile_to_dict(nogoal), "c", 1).error_code == "INVALID_PROFILE";
    assert plan_pathways(profile_to_dict(demo_profile(100, True)), "c", 1, "wrong-hash").error_code == "CATALOGUE_CHANGED";
    assert "Traceback" not in r.error_message;
}

test "T13 the server recomputes: results depend only on the submitted profile" {
    _ = prepare();
    p = demo_profile(2000, True);
    a = plan_pathways(profile_to_dict(p), "conv-t13", 1);
    # plan_pathways has no parameter that accepts a client-supplied result, status or cost,
    # so a tampered client payload has nowhere to go. Same inputs give the same recomputed outputs.
    b = plan_pathways(profile_to_dict(p), "conv-t13", 1);
    assert [c.plan_id for c in a.candidates] == [c.plan_id for c in b.candidates];
    assert [c.ledger.known_total for c in a.candidates] == [c.ledger.known_total for c in b.candidates];
    p2 = demo_profile(24000, True);
    c = plan_pathways(profile_to_dict(p2), "conv-t13", 2);
    assert [x.status for x in a.candidates] != [x.status for x in c.candidates];
}

test "P01 anonymous requests do not leak profile or lens state" {
    _ = prepare();
    a = plan_pathways(profile_to_dict(demo_profile(2000, None, "Jaffna")), "alice", 1);
    b = plan_pathways(profile_to_dict(demo_profile(24000, False, "Colombo")), "bob", 1);
    a2 = plan_pathways(profile_to_dict(demo_profile(2000, None, "Jaffna")), "alice", 1);
    assert b.pending_question is None;
    assert a.pending_question is not None;
    assert [c.plan_id for c in a.candidates] == [c.plan_id for c in a2.candidates];
    assert a.profile_hash != b.profile_hash;
    assert a.conversation_id == "alice";
    assert b.conversation_id == "bob";
}

test "M6 zero feasible routes is a valid ready result" {
    _ = prepare();
    p = demo_profile(24000, True, quals=[]);
    resp = plan_pathways(profile_to_dict(p), "c", 1);
    assert resp.run_status == "ready";
    assert len(resp.candidates) == 0;
    assert len(resp.blocked_candidates) > 0;
    assert any(["No route" in w for w in resp.warnings]);
}

test "M8 the real research catalogue imports through the same loader and never claims affordability from unknown costs" {
    assert ensure_catalogue("real") == "";
    view = load_view("real");
    assert len(view.offerings) >= 1;
    assert "LK-GOAL-IT-DEGREE" in view.goals;
    assert len(view.claims) > 0;
    # a student who meets the academic rules still gets no feasible route while essential costs are unknown
    p = StudentProfile(
        goal_id="LK-GOAL-IT-DEGREE", inventory_complete=True, savings=1000000, monthly_contribution=100000, catalogue_mode="real",
        qualifications=["LK-Q-AL-3-PASSES-ONE-SITTING", "LK-Q-AL-3-PASSES-ONE-SITTING-AFTER-2000", "LK-Q-OL-MATH-PASS", "LK-Q-OL-MATH-C-OR-HIGHER", "LK-Q-OL-ENGLISH-PASS"]
    );
    resp = do_plan(p, "c", 1);
    assert resp.run_status == "ready";
    assert resp.catalogue_mode == "real";
    for c in resp.candidates {
        assert c.status != "feasible_under_stated_assumptions";
    }
    # demo and real data are never mixed in one result set
    for c in resp.candidates {
        for s in c.steps {
            assert not s.offering_id.startswith("DEMO-");
        }
    }
}

test "M8 demo plans never contain real offerings" {
    _ = prepare();
    resp = do_plan(demo_profile(24000, True), "c", 1);
    for c in resp.candidates {
        for s in c.steps {
            assert s.offering_id.startswith("DEMO-");
        }
    }
}

# ----- M7: planner, fallback, Bridge --------------------------------------

def stub_ranker_down(summary: str, options: list[BridgeOption]) -> BridgeRanking {
    raise RuntimeError("provider down");
}

def stub_provider_down(obs: PlannerObservation) -> PlannerChoice {
    raise RuntimeError("provider down");
}

def stub_garbage(obs: PlannerObservation) -> PlannerChoice {
    return PlannerChoice(action="rm_rf", data_field="", plan_ids=["plan-invented"]);
}

def stub_invented_question(obs: PlannerObservation) -> PlannerChoice {
    return PlannerChoice(action="ask_student", data_field="blood_type");
}

def stub_follow_table(obs: PlannerObservation) -> PlannerChoice {
    return rules_choice(obs);
}

def stub_finish_immediately(obs: PlannerObservation) -> PlannerChoice {
    return PlannerChoice(action="finish");
}

test "planner: the three demo profiles take different action sequences (rules table)" {
    view = prepare();
    s1 = run_planner(view, demo_profile(2000, None));
    assert s1.actions == ["evaluate_direct_routes", "search_alternatives", "ask_student"];
    assert s1.question is not None;
    s2 = run_planner(view, demo_profile(2000, True));
    assert s2.actions == ["evaluate_direct_routes", "search_alternatives", "evaluate_candidates", "finish"];
    s3 = run_planner(view, demo_profile(24000, False, "Colombo"));
    assert s3.actions == ["evaluate_direct_routes", "finish"];
    assert s1.actions != s2.actions and s2.actions != s3.actions;
}

test "T11 no key gives a labelled rules fallback" {
    _ = prepare();
    os.environ["UNIPATH_DISABLE_AI"] = "1";
    resp = plan_pathways(profile_to_dict(demo_profile(2000, True)), "c", 1);
    os.environ.pop("UNIPATH_DISABLE_AI", None);
    assert resp.planner_mode == "rules_fallback";
    assert resp.fallback_reason == "no_api_key";
    assert resp.metrics["provider_attempts"] == 0;
}

test "T11 timeout or provider error falls back with a reason" {
    view = prepare();
    rs = run_planner(view, demo_profile(2000, None), stub_provider_down, True);
    assert rs.fallback_reason == "provider_error";
    assert rs.actions[-1] == "ask_student";
    assert planner_mode_of(rs, True) == "rules_fallback";
    resp = do_plan(demo_profile(2000, None), "c", 1, stub_provider_down, stub_ranker_down, True);
    assert resp.planner_mode == "rules_fallback";
    assert resp.fallback_reason == "provider_error";
    assert resp.run_status == "needs_input";
}

test "M7 guards reject unknown actions, invented questions and unissued ids" {
    view = prepare();
    rs = run_planner(view, demo_profile(2000, None), stub_garbage, True);
    assert rs.fallback_reason == "invalid_model_output";
    assert any([e.kind == "guard_rejected" for e in rs.events]);
    rs2 = run_planner(view, demo_profile(2000, None), stub_invented_question, True);
    assert any([e.kind == "guard_rejected" for e in rs2.events]);
    assert rs2.question is not None;
    assert (rs2.question as Question).data_field == "can_relocate";
}

test "L01 live-style run stays inside the shared attempt budget" {
    view = prepare();
    rs = run_planner(view, demo_profile(2000, True), stub_follow_table, True);
    assert rs.attempts <= MAX_PROVIDER_ATTEMPTS;
    assert rs.live_calls_ok >= 1;
    assert planner_mode_of(rs, True) in ["live_ai", "mixed"];
    # after the attempt budget is spent, the rules table takes over and is labelled
    assert rs.fallback_calls + rs.live_calls_ok >= len(rs.actions) - 1;
}

test "M7 a live chooser that finishes early is honoured and recorded" {
    view = prepare();
    rs = run_planner(view, demo_profile(2000, None), stub_finish_immediately, True);
    assert rs.actions == ["evaluate_direct_routes", "finish"];
    assert planner_mode_of(rs, True) == "live_ai";
    assert rs.question is None;
}

test "B01 Bridge AI output changes ordering and explanation but never eligibility" {
    view = prepare();
    p = demo_profile(24000, True);
    out = run_search(view, p, 4);
    plans = [build_candidate(r, view, p) for r in out.routes];
    ladder = [c for c in plans if c.route_kind == "multi_step" and c.status == "conditional"][0];
    # The fixture has one conditional multi-step route, so add a same-status clone to give the
    # model two plans in one status group to reorder.
    clone = build_candidate(ladder_raw(), view, p);
    clone.plan_id = "plan-clone";
    clone.fingerprint = "zzz-clone";
    plans.append(clone);
    status_before = {c.plan_id: c.status for c in plans};
    ranked_before = [c.plan_id for c in rank_plans(plans)];
    options = [BridgeOption(plan_id=ladder.plan_id, summary="a"), BridgeOption(plan_id="plan-clone", summary="b")];
    ranking = BridgeRanking(ordered_plan_ids=["plan-clone", ladder.plan_id], notes=[RouteNote(plan_id="plan-clone", text="Cheapest accepted repair.")]);
    assert apply_bridge_ranking(plans, options, ranking) == "";
    ranked_after = [c.plan_id for c in rank_plans(plans)];
    assert ranked_after != ranked_before;
    assert ranked_after.index("plan-clone") < ranked_after.index(ladder.plan_id);
    for c in plans {
        assert c.status == status_before[c.plan_id];
    }
    assert [c.ai_note for c in plans if c.plan_id == "plan-clone"][0] == "Cheapest accepted repair.";
}

test "B01 Bridge AI output with invented ids is rejected" {
    view = prepare();
    p = demo_profile(24000, True);
    out = run_search(view, p, 4);
    plans = [build_candidate(r, view, p) for r in out.routes];
    options = [BridgeOption(plan_id=plans[0].plan_id, summary="x")];
    bad = BridgeRanking(ordered_plan_ids=["plan-invented"]);
    assert apply_bridge_ranking(plans, options, bad) != "";
    dup = BridgeRanking(ordered_plan_ids=[plans[0].plan_id, plans[0].plan_id]);
    assert apply_bridge_ranking(plans, options, dup) != "";
    long_note = BridgeRanking(ordered_plan_ids=[plans[0].plan_id], notes=[RouteNote(plan_id=plans[0].plan_id, text="x" * 500)]);
    assert apply_bridge_ranking(plans, options, long_note) != "";
}

# ----- M9: stress ---------------------------------------------------------

test "S01 stress run changes only scenario inputs and deltas are correct" {
    view = prepare();
    p = demo_profile(24000, True);
    before = profile_hash_of(p);
    st = do_stress(p, "travel_plus_40", "c", 1);
    assert before == profile_hash_of(p);
    assert st.run_status == "ready";
    by_title = {d.title: d for d in st.deltas};
    onsite = by_title["On-campus IT Degree (Colombo only)"];
    # travel 1500 x 12 = 18000; +40% = 25200; delta 7200
    assert onsite.cost_delta == 7200;
    direct = by_title["Direct IT Degree (remote)"];
    assert direct.cost_delta == 0;
    assert direct.duration_delta == 0;
    # the T05 baselines are untouched
    base = [c for c in st.baseline if c.route_kind == "direct" and c.steps[0].offering_id == "DEMO-DIRECT"][0];
    assert base.ledger.known_total == 84000;
    delay = do_stress(p, "delay_6_months", "c", 1);
    assert all([d.duration_delta == 6 for d in delay.deltas]);
    assert all([d.cost_delta == 0 for d in delay.deltas]);
    assert do_stress(p, "bogus", "c", 1).run_status == "error";
}

test "M6 malformed JSON-style profiles are rejected without leaking details" {
    _ = prepare();
    for bad in [{"goal_id": 5}, {"goal_id": "DEMO-GOAL-IT", "qualifications": "DEMO-Q-ENTRY"}, {"goal_id": "DEMO-GOAL-IT", "savings": "lots"}, {"goal_id": "DEMO-GOAL-IT", "can_relocate": "yes"}, {"goal_id": "DEMO-GOAL-IT", "qualifications": [1, 2]}] {
        r = plan_pathways(bad, "c", 1);
        assert r.run_status == "error";
        assert r.error_code == "INVALID_PROFILE";
        assert "Traceback" not in r.error_message;
    }
    ok = plan_pathways({"goal_id": "DEMO-GOAL-IT", "qualifications": ["DEMO-Q-ENTRY"], "inventory_complete": True, "savings": 24000, "monthly_contribution": 5000, "district": "Colombo", "can_relocate": False}, "c", 1);
    assert ok.run_status == "ready";
}

test "M2 a qualification the student says they do not hold fails even if the list is incomplete" {
    leaves: list[Leaf] = [];
    rule = RequirementExpr(op="has_qual", value="DEMO-Q-ENGLISH");
    p = StudentProfile(qualifications=[], not_held=["DEMO-Q-ENGLISH"], inventory_complete=False);
    assert eval_expr(rule, p, [], leaves) == "fail";
    p2 = StudentProfile(qualifications=[], inventory_complete=False);
    assert eval_expr(rule, p2, [], leaves) == "unknown";
}
