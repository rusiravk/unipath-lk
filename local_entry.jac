# Local-development entry for Jac 0.16.x (the newest release on PyPI), whose module loader does
# not accept the 0.34-era template shape used by main.jac. JacHammer (Jac 0.34.23) uses main.jac.
# Run:  jac start local_entry.jac --port 8000
import from backend {
    get_app_info, health, get_catalogue_projection, get_evidence, plan_pathways, run_stress_test,
    PlanResponse, StressResponse, Projection, EvidenceRecord, AppInfo, HealthInfo
}

cl {
    import from .frontend { app as ClientApp }

    def:pub app() -> JsxElement {
        return <ClientApp />;
    }
}
