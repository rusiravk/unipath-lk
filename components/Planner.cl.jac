sv import from ..backend {
    plan_pathways, get_catalogue_projection, run_stress_test, get_evidence, get_app_info,
    PlanResponse, Projection, StressResponse, EvidenceRecord, AppInfo, Question
}

import from .ProfileForm { ProfileForm }
import from .QuestionCard { QuestionCard }
import from .GraphView { GraphView }
import from .RouteCards { RouteCards }
import from .NodeDetails { NodeDetails }
import from .ActivityLog { ActivityLog }
import from .StressPanel { StressPanel }

# The latest revision lives outside React state so a slow, older response can be recognised
# and discarded after an await (state read after an await is a stale snapshot).
glob rev_box: dict[str, int] = {"latest": 0};
glob conv_box: dict[str, str] = {"id": ""};

def all_digits(text: str) -> bool {
    if text == "" {
        return False;
    }
    for ch in text {
        if ch not in "0123456789" {
            return False;
        }
    }
    return True;
}

def conversation_id() -> str {
    if conv_box["id"] == "" {
        conv_box["id"] = "conv-" + str(int(Math.random() * 1000000000));
    }
    return conv_box["id"];
}

def:pub Planner() -> JsxElement {
    has mode: str = "demo";
    has goal_id: str = "";
    has quals: list[str] = [];
    has not_held: list[str] = [];
    has inventory_complete: bool = True;
    has savings: str = "2000";
    has contribution: str = "5000";
    has district: str = "Jaffna";
    has relocate: str = "unknown";
    has study_mode: str = "";
    has skipped: list[str] = [];
    has proj: Projection | None = None;
    has info: AppInfo | None = None;
    has resp: PlanResponse | None = None;
    has stress: StressResponse | None = None;
    has evidence: EvidenceRecord | None = None;
    has loading: bool = False;
    has stress_loading: bool = False;
    has stale: bool = False;
    has error_text: str = "";
    has selected: str = "";

    async can with entry {
        try {
            info = await get_app_info();
        } except Exception {
            error_text = "Could not reach the server. Please try again.";
        }
    }

    async can with [mode] entry {
        try {
            p = await get_catalogue_projection(mode);
            proj = p;
            first = "";
            for n in p.nodes {
                if n.kind == "goal" and first == "" {
                    first = n.node_id;
                }
            }
            goal_id = first;
            if mode == "demo" and len(quals) == 0 {
                quals = ["DEMO-Q-ENTRY"];
            }
        } except Exception {
            error_text = "Could not load the catalogue graph.";
        }
    }

    def mark_dirty() {
        rev_box["latest"] = rev_box["latest"] + 1;
        stale = True;
        loading = False;
        skipped = [];
    }

    def build_profile() -> dict[str, any] {
        sv_val: any = None;
        if all_digits(savings) {
            sv_val = int(savings);
        }
        co_val: any = None;
        if all_digits(contribution) {
            co_val = int(contribution);
        }
        rel: any = None;
        if relocate == "yes" {
            rel = True;
        } elif relocate == "no" {
            rel = False;
        }
        dist: any = None;
        if district != "" {
            dist = district;
        }
        sm: any = None;
        if study_mode != "" {
            sm = study_mode;
        }
        return {
            "goal_id": goal_id, "qualifications": quals, "not_held": not_held, "inventory_complete": inventory_complete,
            "savings": sv_val, "monthly_contribution": co_val, "district": dist, "can_relocate": rel,
            "study_mode": sm, "skipped_fields": skipped, "catalogue_mode": mode
        };
    }

    async def run_plan() -> None {
        rev = rev_box["latest"] + 1;
        rev_box["latest"] = rev;
        loading = True;
        error_text = "";
        stale = False;
        try {
            r = await plan_pathways(build_profile(), conversation_id(), rev, "");
            if r.profile_revision != rev_box["latest"] {
                return;
            }
            loading = False;
            if r.run_status == "error" {
                error_text = r.error_message;
                return;
            }
            resp = r;
            stress = None;
        } except Exception as ex {
            if rev == rev_box["latest"] {
                loading = False;
                error_text = "The request failed. Your inputs are kept; please try again. (" + str(ex) + ")";
            }
        }
    }

    async def run_stress(name: str) -> None {
        stress_loading = True;
        try {
            s = await run_stress_test(build_profile(), name, conversation_id(), rev_box["latest"]);
            stress = s;
        } except Exception {
            error_text = "The stress test failed. Please try again.";
        }
        stress_loading = False;
    }

    async def open_evidence(claim_id: str) -> None {
        try {
            ev = await get_evidence(claim_id, mode);
            evidence = ev;
        } except Exception {
            error_text = "Could not load that evidence record.";
        }
    }

    def on_mode(v: str) {
        mode = v;
        resp = None;
        stress = None;
        selected = "";
        mark_dirty();
    }
    def on_goal(v: str) { goal_id = v; mark_dirty(); }
    def on_toggle_qual(q: str) {
        if q in quals {
            quals = [x for x in quals if x != q];
        } else {
            quals = quals + [q];
        }
        not_held = [x for x in not_held if x != q];
        mark_dirty();
    }
    def on_inventory(v: bool) { inventory_complete = v; mark_dirty(); }
    def on_savings(v: str) { savings = v; mark_dirty(); }
    def on_contribution(v: str) { contribution = v; mark_dirty(); }
    def on_district(v: str) { district = v; mark_dirty(); }
    def on_relocate(v: str) { relocate = v; mark_dirty(); }
    def on_study_mode(v: str) { study_mode = v; mark_dirty(); }

    def on_preset(name: str) {
        if name == "low" {
            savings = "2000";
            district = "Jaffna";
            relocate = "unknown";
        } else {
            savings = "24000";
            district = "Colombo";
            relocate = "no";
        }
        contribution = "5000";
        inventory_complete = True;
        if mode == "demo" {
            quals = ["DEMO-Q-ENTRY"];
        }
        not_held = [];
        mark_dirty();
    }

    async def on_answer(data_field: str, value: str) -> None {
        if data_field == "can_relocate" {
            relocate = "yes" if value == "yes" else "no";
        } elif data_field == "savings" {
            savings = value;
        } elif data_field == "monthly_contribution" {
            contribution = value;
        } elif data_field == "study_mode" {
            study_mode = value;
        } elif data_field.startswith("qualification:") {
            qid = data_field[len("qualification:"):];
            if value == "yes" {
                quals = quals + [qid];
            } else {
                not_held = not_held + [qid];
            }
        }
        await run_plan();
    }

    async def on_skip(data_field: str) -> None {
        skipped = skipped + [data_field];
        await run_plan();
    }

    def on_select(id: str) { selected = id; }
    def on_close_evidence() { evidence = None; }
    def on_submit() { run_plan(); }

    pending: Question | None = None;
    if resp is not None and not stale {
        pending = resp.pending_question;
    }
    banner = "";
    if info and mode == "demo" {
        banner = info.banner;
    } elif mode == "real" {
        banner = "Real catalogue: no records have been reviewed yet, so no routes can be shown from it.";
    }
    planner_chip = "";
    if resp {
        planner_chip = "Planner: " + resp.planner_mode + (" (" + resp.fallback_reason + ")" if resp.fallback_reason != "" else "");
    }

    return <main className="min-h-screen bg-background text-foreground">
        <header className="border-b border-border">
            <div className="mx-auto flex max-w-[1500px] flex-wrap items-center justify-between gap-2 px-4 py-3">
                <div>
                    <h1 className="text-xl font-semibold tracking-tight">{"UniPath LK"}</h1>
                    <p className="text-xs text-muted-foreground">{"Education route planning for Sri Lankan post-A/L students. Free, anonymous, no accounts."}</p>
                </div>
                {if planner_chip != "" {
                    <span className="rounded-md border border-border px-2 py-1 text-xs" title="AI proposes, rules decide. Fallback is never presented as AI reasoning.">{planner_chip}</span>
                }}
            </div>
            {if banner != "" {
                <div className="bg-amber-100 px-4 py-2 text-center text-sm font-semibold text-amber-950" role="note">{banner}</div>
            }}
        </header>
        {if error_text != "" {
            <div className="mx-auto mt-3 max-w-[1500px] rounded-md border border-red-300 bg-red-50 px-4 py-2 text-sm text-red-900" role="alert">{error_text}</div>
        }}
        <div className="mx-auto grid max-w-[1500px] gap-4 p-4 lg:grid-cols-[320px_minmax(0,1fr)_400px]">
            <aside className="flex flex-col gap-4">
                <ProfileForm
                    proj={proj} mode={mode} goal_id={goal_id} quals={quals} inventory_complete={inventory_complete}
                    savings={savings} contribution={contribution} district={district} relocate={relocate} study_mode={study_mode}
                    loading={loading}
                    onMode={on_mode} onGoal={on_goal} onToggleQual={on_toggle_qual} onInventory={on_inventory}
                    onSavings={on_savings} onContribution={on_contribution} onDistrict={on_district}
                    onRelocate={on_relocate} onStudyMode={on_study_mode} onPreset={on_preset} onSubmit={on_submit}
                />
                <QuestionCard question={pending} loading={loading} onAnswer={on_answer} onSkip={on_skip} />
                <StressPanel stress={stress} loading={stress_loading} canRun={resp is not None and not stale} onRun={run_stress} />
            </aside>
            <section className="flex min-w-0 flex-col gap-4">
                <GraphView proj={proj} resp={resp} selected={selected} onSelect={on_select} />
                <NodeDetails proj={proj} resp={resp} selected={selected} evidence={evidence} onEvidence={open_evidence} onCloseEvidence={on_close_evidence} />
                <ActivityLog resp={resp} />
            </section>
            <section>
                <RouteCards resp={resp} stale={stale} onSelect={on_select} />
            </section>
        </div>
    </main>;
}
