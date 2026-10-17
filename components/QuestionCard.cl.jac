sv import from ..backend { Question }

def:pub QuestionCard(
    question: Question | None,
    loading: bool,
    onAnswer: Callable[[str, str], None],
    onSkip: Callable[[str], None]
) -> JsxElement {
    has number_text: str = "";

    if not question {
        return <div />;
    }
    q = question;
    def h_num(e: ChangeEvent) { number_text = e.target.value; }
    def h_yes(e: MouseEvent) { onAnswer(q.data_field, "yes"); }
    def h_no(e: MouseEvent) { onAnswer(q.data_field, "no"); }
    def h_send(e: MouseEvent) { onAnswer(q.data_field, number_text); }
    def h_skip(e: MouseEvent) { onSkip(q.data_field); }

    btn = "rounded-md border border-border bg-background px-3 py-1.5 text-sm hover:bg-muted disabled:opacity-50";
    return <section className="flex flex-col gap-2 rounded-xl border-2 border-amber-400 bg-amber-50 p-4 text-amber-950 dark:bg-amber-950 dark:text-amber-100" aria-live="polite">
        <p className="text-xs font-semibold uppercase tracking-wide">{"One question that could change your routes"}</p>
        <p className="text-sm font-medium">{q.text}</p>
        <p className="text-xs">{f"This could change {q.candidates_affected} route(s)."}</p>
        {if q.answer_type == "boolean" {
            <div className="flex gap-2">
                <button type="button" className={btn} disabled={loading} onClick={h_yes}>{"Yes"}</button>
                <button type="button" className={btn} disabled={loading} onClick={h_no}>{"No"}</button>
                <button type="button" className={btn} disabled={loading} onClick={h_skip}>{"Skip"}</button>
            </div>
        }}
        {if q.answer_type != "boolean" {
            <div className="flex gap-2">
                <input className="w-full rounded-md border border-input bg-background px-2 py-1.5 text-sm" value={number_text} onChange={h_num} placeholder="Type your answer" />
                <button type="button" className={btn} disabled={loading or number_text == ""} onClick={h_send}>{"Answer"}</button>
                <button type="button" className={btn} disabled={loading} onClick={h_skip}>{"Skip"}</button>
            </div>
        }}
    </section>;
}
