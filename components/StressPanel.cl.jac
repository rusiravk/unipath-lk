sv import from ..backend { StressResponse }

import from .Badges { status_label }

def:pub StressPanel(
    stress: StressResponse | None,
    loading: bool,
    canRun: bool,
    onRun: Callable[[str], None]
) -> JsxElement {
    def h_travel(e: MouseEvent) { onRun("travel_plus_40"); }
    def h_delay(e: MouseEvent) { onRun("delay_6_months"); }
    btn = "rounded-md border border-border bg-background px-2 py-1 text-xs hover:bg-muted disabled:opacity-50";
    return <section className="flex flex-col gap-2 rounded-xl border border-border bg-card p-4" aria-label="Stress test">
        <h2 className="text-base font-semibold">{"Stress test"}</h2>
        <p className="text-xs text-muted-foreground">{"Re-runs the same engine with one labelled change. Shows absolute differences only: no probabilities."}</p>
        <div className="flex gap-2">
            <button type="button" className={btn} disabled={loading or not canRun} onClick={h_travel}>{"Travel +40%"}</button>
            <button type="button" className={btn} disabled={loading or not canRun} onClick={h_delay}>{"6-month delay"}</button>
        </div>
        {if stress {
            <div className="flex flex-col gap-2 text-xs">
                {if stress.run_status == "error" {
                    <p role="alert">{stress.error_message}</p>
                }}
                <ul className="list-disc pl-5 text-muted-foreground">
                    {for a in stress.assumptions {
                        <li key={a}>{a}</li>
                    }}
                </ul>
                {for d in stress.deltas {
                    <div key={d.plan_id} className="rounded-md border border-border p-2">
                        <p className="font-medium">{d.title}</p>
                        <p>{"Status: " + status_label(d.baseline_status) + " → " + status_label(d.scenario_status)}</p>
                        <p>
                            {"Cost change: " + (f"{d.cost_delta:+,} LKR" if d.cost_delta is not None else "unknown")}
                            {" · Shortfall change: " + (f"{d.shortfall_delta:+,} LKR" if d.shortfall_delta is not None else "unknown")}
                            {" · Duration change: " + (f"{d.duration_delta:+} month(s)" if d.duration_delta is not None else "unknown")}
                        </p>
                        {if d.note != "" {
                            <p className="text-muted-foreground">{d.note}</p>
                        }}
                    </div>
                }}
            </div>
        }}
    </section>;
}
