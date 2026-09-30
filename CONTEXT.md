# Roche

A native macOS GUI wrapper for the Mole CLI system monitor and maintenance engine.

## Language

### Core & Engine

**Mole**:
The underlying command-line tool (`mo`) providing macOS system telemetry, cache cleaning, and optimization.
_Avoid_: Backend, CLI utility, Subprocess

**Seam**:
The boundary protocol (`MoleClientProtocol`) separating SwiftUI views from process execution and CLI plumbing.
_Avoid_: API boundary, Service layer

**Executable Resolver**:
The mechanism locating the `mo` or `status-go` binary across Homebrew prefixes, app bundles, and developer environments.
_Avoid_: Binary locator, Path searcher

### Telemetry & Monitoring

**Telemetry**:
Live hardware metrics (CPU, GPU, memory, thermals, battery, disk, processes) emitted by `mo status --json`.
_Avoid_: Metrics dump, System status, Stats

**Health Score**:
An aggregated system condition rating from 0 to 100 calculated by Mole algorithms.
_Avoid_: System grade, Condition index

**Thermal Reading**:
Live sensor telemetry capturing CPU/GPU/battery temperatures and cooling fan speeds.
_Avoid_: Temperature metric, Heat status

### Maintenance & Cleaning

**Clean Scan**:
A dry-run analysis (`mo clean --dry-run`) enumerating reclaimable storage without modifying the filesystem.
_Avoid_: Dry run, Clean preview, Audit

**Clean Action**:
An executed maintenance operation purging selected cache or leftover categories.
_Avoid_: Purge run, Delete task, Wipe

**Clean Category**:
A distinct bucket of reclaimable items such as developer artifacts, application caches, or system logs.
_Avoid_: Clean type, Target, Group


**App Uninstaller**:
The capability discovering installed applications and removing their binaries and associated residual files.
_Avoid_: App remover, Program deleter

**System Optimization**:
The execution of safe maintenance routines repairing system configurations, flushing DNS, and refreshing caches.
_Avoid_: System tuneup, Speedup

**Project Purge**:
The scanning and purging of obsolete build artifacts (`node_modules`, `target`, `.build`) across developer directories.
_Avoid_: Code cleaner, Repo wiper

**Installer Cleanup**:
The detection and removal of obsolete disk images and installer packages (`.dmg`, `.pkg`).
_Avoid_: Package cleaner, File deleter

**Cleanup History**:
The structured audit trail recording past clean and uninstall actions with timestamps and reclaimed capacity.
_Avoid_: Action log, History record

### System Privileges

**Privilege Escalation**:
The secure macOS authorization mechanism prompting for administrator credentials to execute root-level maintenance tasks.
_Avoid_: Root hack, Sudo bypass
### UI & Design System

**Liquid Bento**:
The hybrid design language combining asymmetrical Bento grid hierarchy with macOS Liquid Glassmorphism (`.ultraThinMaterial`, specular borders, and dynamic reactive glows).
_Avoid_: Dashboard UI, Dark mode theme, Grid layout

**Bento Tile**:
A modular, self-contained glass card dedicated to presenting a specific hardware subsystem or health metric.
_Avoid_: Dashboard widget, Metric card, Panel

**Specular Border**:
A subtle directional gradient stroke (`LinearGradient` top-left to bottom-right) simulating light reflection on beveled glass edges.
_Avoid_: Card border, Outline, Stroke

**Adaptive Glow**:
A hardware-state-driven radial luminescence shifting hue from emerald/cyan (nominal) through amber (elevated) to crimson (saturated or thermal limit).
_Avoid_: Dynamic lighting, Status color, Glow effect
