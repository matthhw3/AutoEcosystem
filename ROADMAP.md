# Roadmap

- [x] M0: inspect empty folder, installed Godot and Git; establish architecture and repository policy.
- [x] M1: procedural forest, spectator camera, independent wolf/deer agents, perception/needs, hunt/flee, selection/follow/inspection, simulation controls and local saves; tested headless scene and graphical startup on RTX 5070.
- [x] M2: environmental events, persistent danger memories, reproduction, aging/death; regression tests for state continuity and ecological transitions pass.
- [ ] M3: improve presentation, navigation and observation feedback; endurance and save corruption QA.
- [ ] M4: pack coordination, richer habitats, animal animation and sound using documented assets; profiling before scaling population.

Local Git is initialized on main with the user's confirmed verified author; origin is the public matthhw3/AutoEcosystem repository. Initial component checkpoints exist. Final integrated checkpoint and reviewed push follow QA.

Known prototype limits: distance-based perception without occlusion; animals do not collide with trees; cap of 36 total animal records includes dead animals; no sound; models are procedural block silhouettes; environmental effects are biological rules pending visual feedback. Graphical startup and viewport capture tested; extended human playtesting remains pending.
