# Screen plates

38 plates covering every drawn state in [`../screen-flows.md`](../screen-flows.md),
across commuter, driver and admin.

Published canvas: <https://claude.ai/code/artifact/2939391e-ed93-4165-9549-87f8aeff4c84>

## What is here

| | |
|---|---|
| `*.dc.html` | One artboard per plate. These are the source. |
| `canvas.json` | Layout: positions, the three pages, sticky notes, launch view. |
| `Main.dc.html` | The entry artboard — commuter booking, routed. |

The seeded `trikekoto-screen-plates.html` is **not committed**. It is ~2.6 MB,
almost all of it a bundled editor, and it is regenerated from the files above —
so it is a build artifact rather than source. It is gitignored.

## Drawn from the app, not from imagination

Every value comes from `lib/core/ui/app_theme.dart`: brand amber `#F5A623` on
navy `#101A2C`, the stone neutral ramp, Poppins for anything carrying hierarchy
and the platform face for running text, 48 dp touch targets, 12 px radii, the
13 px type floor.

These record a system that was already built. They are not designs drawn
beforehand, and the roadmap says so — worth stating plainly if a panel asks.

## Re-tracing

`screen-flows.md` is the source of truth for *which* states exist; these files
are the source of truth for what each one *looks like*. Re-trace the document
first when a screen changes, then redraw — a stale table produces a confidently
wrong figure set.

The first version of that document described anonymous commuter entry that
mandatory accounts had already removed, and omitted three screens that existed.
Drawing from it uncovered two live defects in the app itself.
