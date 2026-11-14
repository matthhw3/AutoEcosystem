# Roadmap

- [x] M0: inspect empty folder, installed Godot and Git; establish architecture and repository policy.
- [x] M1: procedural forest, spectator camera, independent wolf/deer agents, perception/needs, hunt/flee, selection/follow/inspection, simulation controls and local saves; tested headless scene and graphical startup on RTX 5070.
- [x] M2: environmental events, persistent danger memories, reproduction, aging/death; regression tests for state continuity and ecological transitions pass.
- [x] M3: visible drought/fire/flood cues, replaceable animated animal proxies, readable panels, roster/follow QA; one-hour endurance and save corruption tests pass. Breeding now requires both parents to reach species-specific maturity.
- [x] M4: spatial resources/thirst, individual traits, coordinated wolves, living-population capacity, save migration, shared habitat geometry and performance validation. One-hour seed42 retains 5 deer/3 wolves; seeds7/2026 retain both species after 30 minutes.
- [x] M5: observation map, improved procedural animal models, original synthesized sound, backup recovery and portable Windows packaging; integrated playtesting. Native Windows Start/Pause/roster interaction verified.
- [x] M6 implementation: multi-seed coexistence balancing, saved expanding fire/flood hazards, drowning/exposure, progressive drought, local observation settings and product acceptance/regression suites. All four automated suites pass.
- [ ] Release qualification: extended hands-on playtesting, sound/presentation assessment, worst-case graphical profiling and resolution/accessibility review. Treat current build as a release candidate, not a finished polished release.
- [ ] Persistent-goal release pass: verify every criterion in RELEASE_ACCEPTANCE.md, resolve independent audit failures, test observable natural generations and obstacle-aware resource journeys, then rebuild and verify distribution.

**Product status: core features implemented; release qualification remains.** The current build goes beyond the initial prototype, but automated acceptance does not establish a fully polished finished game.

Persistent finish goal is active. Checkpoints must proceed to the next unresolved acceptance condition. New audit evidence found long-horizon ecological collapse, unobservable juvenile maturation, corrupt-primary backup loss and underground follow-camera poses. Recovery/camera fixes pass targeted regressions; lifecycle/navigation work is underway. Portable builds now assemble a clean staging directory and archive previous bundles so unlisted files cannot silently ship.

Release-pass progress: recovery/oversized-file/camera tests pass; clean-package stale-file regression passes; deterministic body-clearance A* resolves reproduced water stalls; original articulated models and background landscape pass default/minimum/boundary visual checks. Warmed600-frame normal/stress RTX5070 benchmarks exceed60fps with reported95th-percentile frame timing. Lifecycle balance and final distribution qualification remain active.

Local Git is initialized on main with the user's confirmed verified author; origin is the public matthhw3/AutoEcosystem repository. Initial component and playable-slice checkpoints have been pushed successfully. Safety tooling checks current files and history before pushes.

Known modeling simplifications: local trunk avoidance rather than global path planning; rock/branch geometry has no movement collision; paired reproduction without gestation/genetics; finite spatial resource patches instead of individual plants; stylized procedural models and synthesized ambience; radial hazard expansion rather than fluid/fire physics. Extended human playtesting and broad hardware testing remain pending.
