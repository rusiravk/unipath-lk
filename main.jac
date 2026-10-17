# Entry point. The six public API operations live in backend.jac; importing them here
# registers their /function/<name> routes. The client UI is mounted from frontend.cl.jac.
import from backend {
    get_app_info, health, get_catalogue_projection, get_evidence, plan_pathways, run_stress_test,
    PlanResponse, StressResponse, Projection, EvidenceRecord, AppInfo, HealthInfo
}
import from .frontend { app as ClientApp }

def:pub app() -> JsxElement {
    return <ClientApp />;
}
