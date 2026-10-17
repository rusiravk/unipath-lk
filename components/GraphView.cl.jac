sv import from ..backend { Projection, PlanResponse, ProjNode, ProjEdge }

glob COL_W: int = 210;
glob ROW_H: int = 86;
glob NODE_W: int = 170;
glob NODE_H: int = 58;

glob NODE_STYLE: dict[str, str] = {
    "feasible": "fill-emerald-100 stroke-emerald-600",
    "conditional": "fill-teal-100 stroke-teal-600",
    "needs_confirmation": "fill-amber-100 stroke-amber-500",
    "not_feasible": "fill-red-100 stroke-red-600",
    "blocked": "fill-red-200 stroke-red-800",
    "unreached": "fill-slate-100 stroke-slate-400"
};

glob NODE_TAG: dict[str, str] = {
    "feasible": "✓ feasible",
    "conditional": "◐ conditional",
    "needs_confirmation": "? needs confirmation",
    "not_feasible": "✕ not feasible",
    "blocked": "⛔ blocked",
    "unreached": "· not on a route"
};

def:pub short_label(label: str, limit: int) -> list[str] {
    words = label.split(" ");
    lines: list[str] = [];
    cur = "";
    for w in words {
        if len(cur) + len(w) + 1 > limit and cur != "" {
            lines = lines + [cur];
            cur = w;
        } else {
            cur = (cur + " " + w) if cur != "" else w;
        }
    }
    if cur != "" {
        lines = lines + [cur];
    }
    if len(lines) > 2 {
        lines = [lines[0], lines[1] + "…"];
    }
    return lines;
}

def:pub GraphView(
    proj: Projection | None,
    resp: PlanResponse | None,
    selected: str,
    onSelect: Callable[[str], None]
) -> JsxElement {
    if not proj {
        return <div className="rounded-xl border border-border bg-card p-4 text-sm text-muted-foreground">{"Loading catalogue graph…"}</div>;
    }
    nodes: list[ProjNode] = [];
    for n in proj.nodes {
        if n.kind == "offering" or n.kind == "goal" {
            nodes = nodes + [n];
        }
    }
    if len(nodes) == 0 {
        return <div className="rounded-xl border border-border bg-card p-4 text-sm text-muted-foreground">{"This catalogue has no programmes yet, so there is nothing to draw."}</div>;
    }
    states: dict[str, str] = {};
    shown_edges: dict[str, bool] = {};
    if resp {
        for gs in resp.graph_states {
            states[gs.node_id] = gs.state;
        }
        for c in resp.candidates {
            for st in c.steps {
                if st.via_transition_id != "" {
                    shown_edges[st.via_transition_id] = True;
                }
            }
        }
    }
    pos: dict[str, list[int]] = {};
    max_layer = 0;
    max_row = 0;
    for n in nodes {
        pos[n.node_id] = [20 + n.layer * COL_W, 20 + n.row * ROW_H];
        if n.layer > max_layer {
            max_layer = n.layer;
        }
        if n.row > max_row {
            max_row = n.row;
        }
    }
    width = 40 + max_layer * COL_W + NODE_W;
    height = 40 + max_row * ROW_H + NODE_H;
    edges: list[ProjEdge] = [];
    for e in proj.edges {
        if e.kind == "progresses_to" or e.kind == "supports_goal" {
            edges = edges + [e];
        }
    }

    return <section className="rounded-xl border border-border bg-card p-3" aria-label="Pathway graph">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-base font-semibold">{"Pathway graph"}</h2>
            <p className="text-xs text-muted-foreground">{"Colour and text show status. Bold lines are on a shown route; dashed amber lines are unreviewed. Click a node or line."}</p>
        </div>
        <div className="overflow-x-auto">
            <svg role="img" aria-label="Graph of programmes and the transitions between them" viewBox={f"0 0 {width} {height}"} width={width} height={height} className="max-w-none">
                <defs>
                    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
                        <path d="M 0 0 L 10 5 L 0 10 z" className="fill-slate-500" />
                    </marker>
                </defs>
                {for e in edges {
                    <g key={e.edge_id} onClick={lambda ev: MouseEvent { onSelect(e.edge_id); }} className="cursor-pointer">
                        <line
                            x1={pos[e.source][0] + NODE_W} y1={pos[e.source][1] + NODE_H / 2}
                            x2={pos[e.target][0]} y2={pos[e.target][1] + NODE_H / 2}
                            className={("stroke-slate-700 " if e.edge_id in shown_edges else "stroke-slate-400 ") + ("stroke-amber-600 " if e.status == "unreviewed" else "")}
                            strokeWidth={4 if e.edge_id == selected else (3 if e.edge_id in shown_edges else 1.5)}
                            strokeDasharray={"6 4" if (e.status == "unreviewed" or e.label == "re_entry") else "0"}
                            markerEnd="url(#arrow)"
                        />
                        <title>{f"{e.label or e.kind} ({e.status})"}</title>
                    </g>
                }}
                {for n in nodes {
                    <g key={n.node_id} onClick={lambda ev: MouseEvent { onSelect(n.node_id); }} className="cursor-pointer" tabIndex={0} role="button" aria-label={n.label}>
                        <rect
                            x={pos[n.node_id][0]} y={pos[n.node_id][1]} width={NODE_W} height={NODE_H}
                            rx={29 if n.kind == "goal" else 8}
                            className={NODE_STYLE[states.get(n.node_id, "unreached")] if n.kind == "offering" else "fill-violet-100 stroke-violet-600"}
                            strokeWidth={4 if n.node_id == selected else 2}
                        />
                        {for (i, line) in enumerate(short_label(n.label, 24)) {
                            <text key={str(i)} x={pos[n.node_id][0] + 8} y={pos[n.node_id][1] + 18 + i * 14} className="fill-slate-900 text-[11px] font-medium">{line}</text>
                        }}
                        <text x={pos[n.node_id][0] + 8} y={pos[n.node_id][1] + NODE_H - 6} className="fill-slate-700 text-[10px]">
                            {("🎯 goal" if n.kind == "goal" else NODE_TAG[states.get(n.node_id, "unreached")])}
                        </text>
                    </g>
                }}
            </svg>
        </div>
    </section>;
}
