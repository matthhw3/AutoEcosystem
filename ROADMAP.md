# Roadmap

- [x] M0: inspect empty folder, installed Godot and Git; establish architecture and repository policy.
- [x] M1: procedural forest, spectator camera, independent wolf/deer agents, perception/needs, hunt/flee, selection/follow/inspection, simulation controls and local saves; tested headless scene and graphical startup on RTX 5070.
- [x] M2: environmental events, persistent danger memories, reproduction, aging/death; regression tests for state continuity and ecological transitions pass.
- [x] M3: visible drought/fire/flood cues, replaceable animated animal proxies, readable panels, roster/follow QA; one-hour endurance and save corruption tests pass. Breeding now requires both parents to reach species-specific maturity.
- [ ] M4: pack coordination, richer habitats, animal animation and sound using documented assets; profiling before scaling population.

Local Git is initialized on main with the user's confirmed verified author; origin is the public matthhw3/AutoEcosystem repository. Initial component and playable-slice checkpoints have been pushed successfully. Safety tooling checks current files and history before pushes.

Known prototype limits: distance-based perception without occlusion; animals do not collide with trees; cap of 36 total animal records includes dead animals; no sound; models are procedural block silhouettes; global forage rather than individual plants; floods trigger evacuation and forage loss but no drowning; wildfire does not spread. Graphical startup and viewport captures tested; extended human playtesting remains pending.
