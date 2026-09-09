# Documentation

| File | What it is |
|---|---|
| [`build-order.html`](build-order.html) | The 97-step roadmap, with progress by area. Open in a browser. |
| [`field-test-log.html`](field-test-log.html) | Fillable end-to-end test sheet, 56 steps over 11 phases. Saves in the browser as you go; **Export log** produces Markdown for the appendix. |
| [`screen-flows.md`](screen-flows.md) | Role flows and the screen state inventory, traced from the code. |
| [`wireframes/`](wireframes/) | 38 screen plates drawn from those flows. |
| [`RUNBOOK.md`](RUNBOOK.md) | What to do when something breaks during the pilot. |
| [`admin-guide.md`](admin-guide.md) · [`driver-guide.md`](driver-guide.md) · [`commuter-guide.md`](commuter-guide.md) | End-user manuals, in Filipino. |
| [`pilot-plan.md`](pilot-plan.md) | One TODA chapter, monitored daily, with the rollback. |
| [`uat-kit.md`](uat-kit.md) | User acceptance testing pack. |

## Source of truth

**These files are the source. The published artifacts are a view of them.**

The two HTML documents are also published as live artifacts so they can be
read and shared without a checkout:

- Build order — <https://claude.ai/code/artifact/5dc60ba0-b332-415d-8001-a82a92bb19e2>
- Field test log — <https://claude.ai/code/artifact/2b750416-cfdd-44fb-a33c-9b72cfa47b86>

Edit the file here, then republish it to the same URL. Never the other way
round: an edit made in the artifact and not brought back is lost the next time
the file is published, silently and with no conflict to warn you.

The one exception is the field test log, which **stores your results in the
browser you fill it in on**, not in the file. Republishing replaces the sheet,
not the answers — but export the log before a republish if a run is in
progress, because a changed sheet and a half-finished run are not comparable.
