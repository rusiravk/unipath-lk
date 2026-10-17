glob STATUS_LABEL: dict[str, str] = {
    "feasible_under_stated_assumptions": "Feasible under stated assumptions",
    "conditional": "Conditional",
    "needs_confirmation": "Needs confirmation",
    "not_feasible_under_current_inputs": "Not feasible with current inputs",
    "feasible": "Feasible",
    "not_feasible": "Not feasible",
    "blocked": "Blocked",
    "unreached": "Not on any route"
};

glob STATUS_ICON: dict[str, str] = {
    "feasible_under_stated_assumptions": "✓",
    "feasible": "✓",
    "conditional": "◐",
    "needs_confirmation": "?",
    "not_feasible_under_current_inputs": "✕",
    "not_feasible": "✕",
    "blocked": "⛔",
    "unreached": "·"
};

glob STATUS_CLASS: dict[str, str] = {
    "feasible_under_stated_assumptions": "bg-emerald-100 text-emerald-900 border-emerald-300 dark:bg-emerald-950 dark:text-emerald-200 dark:border-emerald-800",
    "feasible": "bg-emerald-100 text-emerald-900 border-emerald-300 dark:bg-emerald-950 dark:text-emerald-200 dark:border-emerald-800",
    "conditional": "bg-teal-100 text-teal-900 border-teal-300 dark:bg-teal-950 dark:text-teal-200 dark:border-teal-800",
    "needs_confirmation": "bg-amber-100 text-amber-900 border-amber-300 dark:bg-amber-950 dark:text-amber-200 dark:border-amber-800",
    "not_feasible_under_current_inputs": "bg-red-100 text-red-900 border-red-300 dark:bg-red-950 dark:text-red-200 dark:border-red-800",
    "not_feasible": "bg-red-100 text-red-900 border-red-300 dark:bg-red-950 dark:text-red-200 dark:border-red-800",
    "blocked": "bg-red-100 text-red-900 border-red-300 dark:bg-red-950 dark:text-red-200 dark:border-red-800",
    "unreached": "bg-muted text-muted-foreground border-border"
};

glob EVIDENCE_CLASS: dict[str, str] = {
    "verified": "bg-emerald-50 text-emerald-800 border-emerald-300",
    "fixture": "bg-slate-100 text-slate-700 border-slate-300",
    "unreviewed": "bg-amber-50 text-amber-800 border-amber-400 border-dashed",
    "stale": "bg-orange-50 text-orange-800 border-orange-300",
    "rejected": "bg-red-50 text-red-800 border-red-300"
};

def:pub status_label(s: str) -> str {
    if s in STATUS_LABEL {
        return STATUS_LABEL[s];
    }
    return s;
}

def:pub status_icon(s: str) -> str {
    if s in STATUS_ICON {
        return STATUS_ICON[s];
    }
    return "·";
}

def:pub status_class(s: str) -> str {
    if s in STATUS_CLASS {
        return STATUS_CLASS[s];
    }
    return "bg-muted text-muted-foreground border-border";
}

def:pub lkr(n: int | None) -> str {
    if n is None {
        return "unknown";
    }
    return f"LKR {n:,}";
}

def:pub StatusBadge(status: str) -> JsxElement {
    return <span className={"inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs font-medium " + status_class(status)}>
        <span aria-hidden="true">{status_icon(status)}</span>
        <span>{status_label(status)}</span>
    </span>;
}

def:pub EvidenceBadge(status: str) -> JsxElement {
    cls = "bg-muted text-muted-foreground border-border";
    if status in EVIDENCE_CLASS {
        cls = EVIDENCE_CLASS[status];
    }
    label = "evidence: " + status if status != "" else "no evidence recorded";
    return <span className={"inline-flex items-center rounded-md border px-2 py-0.5 text-xs " + cls}>{label}</span>;
}
