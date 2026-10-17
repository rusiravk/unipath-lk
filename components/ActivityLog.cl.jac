sv import from ..backend { PlanResponse }

def:pub ActivityLog(resp: PlanResponse | None) -> JsxElement {
    if not resp {
        return <div />;
    }
    seq_text = "";
    for a in resp.action_sequence {
        seq_text = (seq_text + " → " + a) if seq_text != "" else a;
    }
    return <details className="rounded-xl border border-border bg-card p-3" open={True}>
        <summary className="cursor-pointer text-sm font-semibold">{"Activity log"}</summary>
        <div className="mt-2 flex flex-col gap-2 text-xs">
            <p>
                <span className="font-medium">{"Planner mode: "}</span>
                <span>{resp.planner_mode}</span>
                {if resp.fallback_reason != "" {
                    <span>{" (reason: " + resp.fallback_reason + ")"}</span>
                }}
            </p>
            <p>
                <span className="font-medium">{"Actions taken: "}</span>
                <span>{seq_text}</span>
            </p>
            <ol className="flex flex-col gap-1">
                {for ev in resp.decision_events {
                    <li key={str(ev.seq)} className="flex gap-2">
                        <span className="text-muted-foreground">{f"{ev.seq}."}</span>
                        <span className="rounded border border-border px-1 text-[10px] uppercase">{ev.actor}</span>
                        <span>{ev.message}</span>
                    </li>
                }}
            </ol>
            <p className="text-muted-foreground">
                {f"Expanded states: {resp.metrics['expanded_states']} · provider attempts: {resp.metrics['provider_attempts']} · routes found: {resp.metrics['routes_found']} · time: {resp.metrics['elapsed_ms']} ms" + (" · search limits were reached" if resp.search_truncated else "")}
            </p>
        </div>
    </details>;
}
