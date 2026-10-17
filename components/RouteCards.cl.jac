sv import from ..backend { PlanResponse, CandidatePlan, BlockedItem }

import from .Badges { StatusBadge, EvidenceBadge, lkr }

def:pub RouteCard(plan: CandidatePlan, rank: int, resp: PlanResponse, onSelect: Callable[[str], None]) -> JsxElement {
    def h_select(e: MouseEvent) {
        onSelect(plan.steps[len(plan.steps) - 1].offering_id);
    }
    lg = plan.ledger;
    kind = "Direct route" if plan.route_kind == "direct" else f"{len(plan.steps)}-step route";
    return <article className="flex flex-col gap-2 rounded-xl border border-border bg-card p-4" aria-label={f"Route {rank}"}>
        <div className="flex flex-wrap items-center gap-2">
            <span className="text-sm font-semibold">{f"#{rank} {kind}"}</span>
            <StatusBadge status={plan.status} />
            <EvidenceBadge status={plan.evidence_status} />
        </div>
        <ol className="flex flex-col gap-1 text-sm">
            {for (i, st) in enumerate(plan.steps) {
                <li key={st.offering_id} className="flex flex-col">
                    <span className="font-medium">{f"{i + 1}. {st.title}"}</span>
                    <span className="text-xs text-muted-foreground">
                        {f"{st.institution_name} · {st.delivery_mode or 'mode not stated'} · {st.duration_months or 'duration unknown'} month(s)" + ((" · via " + st.via_type) if st.via_type != "" else "")}
                    </span>
                    {for f in resp.findings {
                        if f.candidate_id == plan.plan_id and f.node_id == st.offering_id and f.lens == "Fiscal" and (f.rule_id == "step_costs" or f.rule_id == "cost_unknown") {
                            <span key={f.rule_id} className="text-xs">{f.message}</span>
                        }
                    }}
                </li>
            }}
        </ol>
        <dl className="grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
            <dt className="text-muted-foreground">{"Total cost (known)"}</dt>
            <dd className="font-medium">{lkr(lg.known_total) if lg.complete else "incomplete: " + lkr(lg.known_total) + " known"}</dd>
            <dt className="text-muted-foreground">{"Duration"}</dt>
            <dd className="font-medium">{f"{lg.duration_months} month(s)" if lg.duration_months is not None else "unknown"}</dd>
            <dt className="text-muted-foreground">{"Lowest balance"}</dt>
            <dd className="font-medium">{lkr(lg.minimum_balance)}</dd>
            <dt className="text-muted-foreground">{"Extra cash needed first"}</dt>
            <dd className="font-medium">{lkr(lg.extra_initial_cash)}</dd>
        </dl>
        <p className="text-xs">{plan.status_reason}</p>
        {if len(plan.conditions) > 0 {
            <div>
                <p className="text-xs font-semibold">{"Conditions"}</p>
                <ul className="list-disc pl-5 text-xs">
                    {for c in plan.conditions {
                        <li key={c}>{c}</li>
                    }}
                </ul>
            </div>
        }}
        {if len(plan.next_actions) > 0 {
            <div>
                <p className="text-xs font-semibold">{"Next actions"}</p>
                <ul className="list-disc pl-5 text-xs">
                    {for a in plan.next_actions {
                        <li key={a}>{a}</li>
                    }}
                </ul>
            </div>
        }}
        {if plan.ai_note != "" {
            <p className="rounded-md bg-violet-50 p-2 text-xs text-violet-900">{"AI-written note (does not decide eligibility): " + plan.ai_note}</p>
        }}
        {if len(lg.assumptions) > 0 {
            <details className="text-xs text-muted-foreground">
                <summary className="cursor-pointer">{"Assumptions"}</summary>
                <ul className="list-disc pl-5">
                    {for a in lg.assumptions {
                        <li key={a}>{a}</li>
                    }}
                </ul>
            </details>
        }}
        <div className="flex items-center justify-between text-xs text-muted-foreground">
            <span>{"Last checked: not reviewed (no source dates recorded)"}</span>
            <button type="button" onClick={h_select} className="underline">{"Show lens notes"}</button>
        </div>
    </article>;
}

def:pub RouteCards(resp: PlanResponse | None, stale: bool, onSelect: Callable[[str], None]) -> JsxElement {
    if not resp {
        return <section className="rounded-xl border border-border bg-card p-4 text-sm text-muted-foreground">{"Fill in your situation and press “Find my routes”."}</section>;
    }
    return <section className={"flex flex-col gap-3 " + ("opacity-60" if stale else "")} aria-label="Routes">
        <h2 className="text-base font-semibold">{"Routes"}</h2>
        {if stale {
            <p className="rounded-md border border-amber-400 bg-amber-50 p-2 text-xs text-amber-900" role="status">{"Your inputs changed. These results are out of date until you press “Find my routes” again."}</p>
        }}
        {if len(resp.candidates) == 0 {
            <p className="rounded-md border border-border bg-card p-3 text-sm">{"No route reaches this goal under the stated inputs. See the excluded options below for the reasons."}</p>
        }}
        {for (i, c) in enumerate(resp.candidates) {
            <RouteCard key={c.plan_id} plan={c} rank={i + 1} resp={resp} onSelect={onSelect} />
        }}
        {if resp.bridge_note != "" {
            <p className="text-xs text-muted-foreground">{resp.bridge_note}</p>
        }}
        {if len(resp.blocked_candidates) > 0 {
            <div className="rounded-xl border border-border bg-card p-3">
                <h3 className="text-sm font-semibold">{"Why an option was excluded"}</h3>
                <ul className="mt-1 flex flex-col gap-1 text-xs">
                    {for b in resp.blocked_candidates {
                        <li key={b.blocked_id}>{b.message}</li>
                    }}
                </ul>
            </div>
        }}
        {for w in resp.warnings {
            <p key={w} className="text-xs text-muted-foreground">{w}</p>
        }}
    </section>;
}
