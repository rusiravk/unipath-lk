"""UniPath LK client entry. The shell state lives in components/Planner.cl.jac."""

cl import ".styles.global.css";
cl import from ".components.Planner" { Planner }

cl def:pub app() -> JsxElement {
    return <Planner />;
}
