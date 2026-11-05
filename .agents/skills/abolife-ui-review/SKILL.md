---
name: abolife-ui-review
description: Review or refine AboLife's native macOS UI while preserving the original dashboard, correct budget meanings, Reduce Motion and isolated visual fixtures. Use for AboLife SwiftUI layout, motion or visual QA.
---

Read the repository AGENTS.md and docs/UI_SPEC.md. AboLife uses GRDB; dormant SwiftData training declarations are not a data source. Preserve the matte graphite/card/ring dashboard composition, SF typography and restrained blue actions. Use adaptive AboLifeColors and the spacing/radius/motion tokens; retain macOS 14 support.

Check the actual page at a 660-point detail width and a wider window, in both appearances. Inspect sheets on a short window: scrolling content, reachable actions, focus, Escape, disabled input and genuine save failure. Native macOS controls should retain keyboard behavior. Use meaningful text labels for symbol buttons.

Budget invariants: finance ring = monthly amount spent; menu ring = today's available share of the entire monthly budget. Today's spending is subtracted in full after allocating the remaining budget. Do not reinterpret those formulas as part of visual work.

Only recorded entries support personal statistics. No sample training results, fabricated history, interpolated missing weights or forecast presented as fact. Label periods and current target settings in historic views. Keep human review drafts across sidebar navigation; confirm before discarding on period/reload changes.

Use ABOLIFE_DEMO=1 or the demo bundle for live QA. Render the real DashboardView.overview composition through EvolutionRenderingTests using ABOLIFE_RENDER_DIR; ImageRenderer does not prove native text-field/window behavior or animation quality. Do not use private data for screenshots. Add representative empty, over-budget and long-text states when relevant. Record genuine differences, failed checks and untested interactions, then rerun affected checks after fixes.
