sv import from ..backend { Projection, PlanResponse, EvidenceRecord, Finding }

import from .Badges { EvidenceBadge, status_label }

glob LENSES: list[str] = ["Aspiration", "Fiscal", "Gatekeeper", "Bridge"];
glob RESULT_MARK: dict[str, str] = {"pass": "✓", "fail": "✕", "unknown": "?", "info": "•"};

def result_mark(r: str) -> str {
    if r in RESULT_MARK {
        return RESULT_MARK[r];
    }
    return "•";
}

def lens_count(items: list[Finding], ln: str) -> int {
    n = 0;
    for f in items {
        if f.lens == ln {
            n += 1;
        }
    }
    return n;
}

def:pub NodeDetails(
    proj: Projection | None,
    resp: PlanResponse | None,
    selected: str,
    evidence: EvidenceRecord | None,
    onEvidence: Callable[[str], None],
    onCloseEvidence: Callable[[], None]
) -> JsxElement {
    def h_close(e: MouseEvent) { onCloseEvidence(); }
    if not proj or selected == "" {
        return <section className="rounded-xl border border-border bg-card p-3 text-sm text-muted-foreground">{"Select a node or line in the graph to see its rule, the four lens findings and the evidence."}</section>;
    }
    title = selected;
    detail = "";
    kind = "transition";
    for n in proj.nodes {
        if n.node_id == selected {
            title = n.label;
            detail = n.detail;
            kind = n.kind;
        }
    }
    edge_info = "";
    for e in proj.edges {
        if e.edge_id == selected {
            title = f"Transition {e.edge_id}";
            edge_info = f"{e.label or e.kind}; evidence status: {e.status or 'n/a'}";
        }
    }
    state = "";
    items: list[Finding] = [];
    if resp is not None {
        for gs in resp.graph_states {
            if gs.node_id == selected {
                state = status_label(gs.state);
            }
        }
        for fnd in resp.findings {
            if fnd.node_id == selected or fnd.rule_id == selected {
                items = items + [fnd];
            }
        }
    }

    return <section className="flex flex-col gap-2 rounded-xl border border-border bg-card p-4" aria-label="Details">
        <h3 className="text-sm font-semibold">{title}</h3>
        <p className="text-xs text-muted-foreground">{detail or edge_info}</p>
        {if state != "" {
            <p className="text-xs">{"Status on current routes: " + state}</p>
        }}
        {for ln in LENSES {
            <div key={ln}>
                <p className="text-xs font-semibold">{ln + " lens"}</p>
                {if lens_count(items, ln) == 0 {
                    <p className="text-xs text-muted-foreground">{"Not applicable to this selection."}</p>
                }}
                <ul className="flex flex-col gap-0.5 text-xs">
                    {for (i, f) in enumerate(items) {
                        if f.lens == ln {
                            <li key={f.rule_id + str(i)} className="flex flex-wrap items-center gap-1">
                                <span aria-hidden="true">{result_mark(f.result)}</span>
                                <span>{f.message}</span>
                                {if f.evidence_status != "" {
                                    <EvidenceBadge status={f.evidence_status} />
                                }}
                                {for cid in f.evidence_ids {
                                    <button key={cid} type="button" className="underline" onClick={lambda ev: MouseEvent { onEvidence(cid); }}>{"view " + cid}</button>
                                }}
                            </li>
                        }
                    }}
                </ul>
            </div>
        }}
        {if evidence {
            <div className="rounded-md border border-border bg-muted p-2 text-xs" role="region" aria-label="Evidence record">
                <div className="flex items-center justify-between">
                    <span className="font-semibold">{evidence.claim_id}</span>
                    <button type="button" className="underline" onClick={h_close}>{"close"}</button>
                </div>
                <EvidenceBadge status={evidence.status} />
                <p>{evidence.subject}</p>
                <p>{"Source: " + (evidence.source_title or "none recorded")}</p>
                <p>{"Excerpt: " + (evidence.excerpt or "none")}</p>
                <p>{"URL: " + (evidence.source_url or "none (fixture or unreviewed)")}</p>
                <p>{"Checked: " + (evidence.checked_date or "not checked")}</p>
            </div>
        }}
    </section>;
}
