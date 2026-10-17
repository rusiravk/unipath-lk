sv import from ..backend { Projection, ProjNode }

glob DISTRICTS: list[str] = ["Colombo", "Gampaha", "Kandy", "Galle", "Jaffna", "Kurunegala", "Anuradhapura", "Other"];

def:pub ProfileForm(
    proj: Projection | None,
    mode: str,
    goal_id: str,
    quals: list[str],
    inventory_complete: bool,
    savings: str,
    contribution: str,
    district: str,
    relocate: str,
    study_mode: str,
    loading: bool,
    onMode: Callable[[str], None],
    onGoal: Callable[[str], None],
    onToggleQual: Callable[[str], None],
    onInventory: Callable[[bool], None],
    onSavings: Callable[[str], None],
    onContribution: Callable[[str], None],
    onDistrict: Callable[[str], None],
    onRelocate: Callable[[str], None],
    onStudyMode: Callable[[str], None],
    onPreset: Callable[[str], None],
    onSubmit: Callable[[], None]
) -> JsxElement {
    def h_mode(e: ChangeEvent) { onMode(e.target.value); }
    def h_goal(e: ChangeEvent) { onGoal(e.target.value); }
    def h_inv(e: ChangeEvent) { onInventory(e.target.checked); }
    def h_sav(e: ChangeEvent) { onSavings(e.target.value); }
    def h_con(e: ChangeEvent) { onContribution(e.target.value); }
    def h_dis(e: ChangeEvent) { onDistrict(e.target.value); }
    def h_rel(e: ChangeEvent) { onRelocate(e.target.value); }
    def h_sm(e: ChangeEvent) { onStudyMode(e.target.value); }
    def h_low(e: MouseEvent) { onPreset("low"); }
    def h_high(e: MouseEvent) { onPreset("high"); }
    def h_submit(e: FormEvent) {
        e.preventDefault();
        onSubmit();
    }

    goals: list[ProjNode] = [];
    qual_nodes: list[ProjNode] = [];
    if proj is not None {
        for n in proj.nodes {
            if n.kind == "goal" {
                goals = goals + [n];
            }
            if n.kind == "qualification" {
                qual_nodes = qual_nodes + [n];
            }
        }
    }
    field = "w-full rounded-md border border-input bg-background px-2 py-1.5 text-sm";
    label = "mb-1 block text-xs font-medium text-muted-foreground";

    return <form onSubmit={h_submit} className="flex flex-col gap-3 rounded-xl border border-border bg-card p-4" aria-label="Student profile">
        <h2 className="text-base font-semibold">{"Your situation"}</h2>
        <div className="flex gap-2">
            <button type="button" onClick={h_low} className="rounded-md border border-border px-2 py-1 text-xs hover:bg-muted">{"Example: low savings"}</button>
            <button type="button" onClick={h_high} className="rounded-md border border-border px-2 py-1 text-xs hover:bg-muted">{"Example: high savings"}</button>
        </div>
        <div>
            <label className={label} htmlFor="mode">{"Catalogue"}</label>
            <select id="mode" className={field} value={mode} onChange={h_mode}>
                <option value="demo">{"Demonstration (fictional)"}</option>
                <option value="real">{"Real (research data, partly reviewed)"}</option>
            </select>
        </div>
        <div>
            <label className={label} htmlFor="goal">{"Goal"}</label>
            <select id="goal" className={field} value={goal_id} onChange={h_goal}>
                {if len(goals) == 0 {
                    <option value="">{"No goals in this catalogue"}</option>
                }}
                {for g in goals {
                    <option key={g.node_id} value={g.node_id}>{g.label}</option>
                }}
            </select>
        </div>
        <fieldset>
            <legend className={label}>{"Qualifications you hold"}</legend>
            {if len(qual_nodes) == 0 {
                <p className="text-xs text-muted-foreground">{"None listed in this catalogue."}</p>
            }}
            {for q in qual_nodes {
                <label key={q.node_id} className="flex items-center gap-2 py-0.5 text-sm">
                    <input type="checkbox" checked={q.node_id in quals} onChange={lambda e: ChangeEvent { onToggleQual(q.node_id); }} />
                    <span>{q.label}</span>
                </label>
            }}
            <label className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                <input type="checkbox" checked={inventory_complete} onChange={h_inv} />
                <span>{"This list is complete (anything not ticked is treated as not held)"}</span>
            </label>
        </fieldset>
        <div className="grid grid-cols-2 gap-2">
            <div>
                <label className={label} htmlFor="savings">{"Savings (LKR)"}</label>
                <input id="savings" type="number" min="0" className={field} value={savings} onChange={h_sav} placeholder="unknown" />
            </div>
            <div>
                <label className={label} htmlFor="contrib">{"Per month (LKR)"}</label>
                <input id="contrib" type="number" min="0" className={field} value={contribution} onChange={h_con} placeholder="unknown" />
            </div>
        </div>
        <div className="grid grid-cols-2 gap-2">
            <div>
                <label className={label} htmlFor="district">{"Where you live"}</label>
                <select id="district" className={field} value={district} onChange={h_dis}>
                    <option value="">{"Not stated"}</option>
                    {for d in DISTRICTS {
                        <option key={d} value={d}>{d}</option>
                    }}
                </select>
            </div>
            <div>
                <label className={label} htmlFor="relocate">{"Can relocate?"}</label>
                <select id="relocate" className={field} value={relocate} onChange={h_rel}>
                    <option value="unknown">{"Not answered"}</option>
                    <option value="yes">{"Yes"}</option>
                    <option value="no">{"No"}</option>
                </select>
            </div>
        </div>
        <div>
            <label className={label} htmlFor="studymode">{"Preferred study mode"}</label>
            <select id="studymode" className={field} value={study_mode} onChange={h_sm}>
                <option value="">{"No preference stated"}</option>
                <option value="any">{"Any"}</option>
                <option value="remote">{"Remote"}</option>
                <option value="on_campus">{"On campus"}</option>
                <option value="hybrid">{"Hybrid"}</option>
            </select>
        </div>
        <button type="submit" disabled={loading or goal_id == ""} className="rounded-md bg-primary px-3 py-2 text-sm font-medium text-primary-foreground disabled:opacity-50">
            {"Searching…" if loading else "Find my routes"}
        </button>
    </form>;
}
