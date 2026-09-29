# Liquid Bento Design System for System Monitoring Telemetry

## Context & Decision
Roche requires a native macOS interface that combines high-density hardware metrics with visual aesthetics matching modern macOS Sequoia and VisionOS standards. We evaluated five distinct UI paradigms (Liquid Glass, Linear Dark, Bento Grid, Nordic Brutalism, and Neumorphic Soft) using runnable prototypes against live Mole telemetry, and decided to adopt **Liquid Bento**—an architectural fusion pairing asymmetrical Bento grid modularity with macOS translucent glassmorphism (`.ultraThinMaterial`), specular gradient borders, and telemetry-driven adaptive glow states.

## Considered Options
- **Pure Liquid Glass**: High visual depth, but uniform card grids degraded information hierarchy for high-priority telemetry like CPU and System Health.
- **Linear Obsidian Dark**: High information density and sharp typography, but lacked native macOS material translucency and depth.
- **Pure Bento Grid**: Superior visual hierarchy, but flat opaque surfaces missed macOS aesthetic fluidity.
- **Nordic Brutalism & Neumorphic Soft**: Strong conceptual identities, but either caused excessive visual friction or bloated render complexity.

## Consequences
- Dashboard views are structured using modular `BentoTile` components arranged in asymmetrical hero/status configurations.
- Specular borders and adaptive luminescence react dynamically to CPU load, memory pressure, and thermal metrics.
- Component primitives are isolated into `UI/Components/LiquidBento/` to maintain clean separation from Mole CLI execution and data models.
