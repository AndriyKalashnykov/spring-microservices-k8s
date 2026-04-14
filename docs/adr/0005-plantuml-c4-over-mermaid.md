# ADR-0005: PlantUML + C4-PlantUML for structural architecture diagrams

- **Status**: Accepted
- **Date**: 2026-04-14
- **Context**: Diagrams-as-code selection after Mermaid ↔ PlantUML side-by-side evaluation

## Decision

Use **PlantUML with the C4-PlantUML stdlib** for structural architecture diagrams (Container, Deployment). Use **Mermaid** for runtime/flow diagrams (sequence, state) where Mermaid renders natively on GitHub without a build step.

## Context

Earlier revisions of the project used inline Mermaid `graph TB` blocks as hero and architecture diagrams. A side-by-side comparison (committed briefly under `<details>` blocks) produced two findings:

1. Mermaid's experimental `C4Context` / `C4Container` renderer has hardcoded washed-out palette colors that can't be overridden. At GitHub render width the output looks weak.
2. Mermaid's `flowchart` with `classDef` brand colors works well visually but carries no C4 semantics — a "container-shaped flowchart" isn't a C4 Container diagram, it just looks like one.

PlantUML with C4-PlantUML:
- Has real C4 shape primitives (`Person`, `Container`, `ContainerDb`, `System_Ext`, `Deployment_Node`)
- Accepts `skinparam` + `UpdateElementStyle` overrides — a 10-line block gets a modern flat teal/indigo/violet palette with Inter font, no shadows, sharp corners
- Requires a build step (`make diagrams` via pinned `plantuml/plantuml` Docker image); rendered PNGs are committed to the repo

Mermaid remains the right tool for sequence diagrams — renders inline with no toolchain, autonumbered arrows pair cleanly with prose captions.

## Alternatives considered

| Option | Verdict |
|--------|---------|
| Mermaid only (all diagrams inline) | Rejected — washed-out C4 rendering, no palette control |
| PlantUML only (including sequence) | Rejected — sequence diagrams don't render inline on GitHub; losing the zero-toolchain advantage for the one diagram type where Mermaid shines |
| draw.io / Excalidraw | Rejected — GUI tools, PNG-only, no diffs, rots silently. Violates diagrams-as-code principle. |
| Structurizr DSL | Considered — "model once, render many" is genuinely attractive at 10+ services, but overkill for 4. Re-evaluate if the service count grows significantly. |
| **PlantUML + C4-PlantUML (structural) + Mermaid (flow)** | **Chosen** — each tool used for what it's best at. |

## Consequences

- `docs/diagrams/*.puml` is committed; rendered `docs/diagrams/out/*.png` are also committed (required for github.com to render the README without a build step).
- `make diagrams-check` is wired into `make static-check` — guards against contributors editing a `.puml` without re-rendering.
- `PLANTUML_VERSION` and `MERMAID_CLI_VERSION` are pinned in the Makefile with Renovate annotations.
- C4-PlantUML `!include` pins to a tagged release (`v2.11.0`), not `master`, to keep rendering reproducible across time.
- PlantUML renderer runs in Docker — contributors need Docker to regenerate diagrams, but not to view them (PNGs are in the repo).

## References

- `docs/diagrams/c4-container.puml` — the modern-flat skinparam template used across all C4 diagrams
- `/architecture-diagrams` skill in `~/.claude/commands/` — full guidance on when to use which tool
- C4 model: [c4model.com](https://c4model.com/)
- C4-PlantUML stdlib: [github.com/plantuml-stdlib/C4-PlantUML](https://github.com/plantuml-stdlib/C4-PlantUML)
