# Architecture and decisions

Godot 4.7.2 / GDScript, compatibility renderer for reliable startup. Procedural low-poly forest prioritizes readable animal behavior. The renderer can be upgraded after profiling; no dependency on an online service.

`scripts/simulation.gd` owns serializable agent state and seeded randomness independently of the scene tree. Fixed 0.1-second ticks run only after Start or explicit Step. Biological needs feed individual behavior choices, while danger and recent experiences persist across ticks/saves. Time scaling schedules extra fixed ticks; camera and UI stay interactive while paused.

`scripts/forest.gd` builds procedural scenery and supplies terrain height. `scripts/spectator_camera.gd` owns free flight/follow. `scripts/main.gd` integrates model, animal visual proxies, UI, picking and persistence. Views never advance agent biology.

Save schema is versioned and JSON based. Random state is stored as a string to preserve 64-bit precision. Save on pause and normal window close; load and launch always pause. No wall clock advancement. Autosave uses a temporary file and backup. Invalid saves must leave the current simulation intact.

Save JSON uses full precision; the parser can still round a double by one ULP. Seeded execution is repeatable, while restored floating values are tested within 1e-12, not promised bit-identical replay. Save errors keep the window open on normal close. Saves live under Godot's `user://` directory (normally `%APPDATA%/Godot/app_userdata/North American Ecosystem`); tests redirect APPDATA to ignored `.local/` and restore any prior test saves.

Validation: `tools/run_tests.ps1 -Godot <console executable>` runs biological and scene integration tests. Integration covers paused startup, start/step, pause autosave, load paused, state restoration and malformed-save rejection. `-- --capture` runs a graphical viewport capture to ignored test-results/observatory.png; `-- --smoke` starts the full scene, steps and exits. Windows sandbox certificate-store warnings are unrelated to runtime networking (the game uses none).

Runtime assets are replaceable visual proxies. Simulation knows species and position, not mesh structure. Future models can replace proxies without changing biological state. Current perception is distance based and terrain movement is height projected; line-of-sight, navigation around obstacles and pack cooperation remain future work.

Research: Godot official documentation on command-line headless execution, saving games and RandomNumberGenerator state informed the testing/persistence design. See https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html and https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html.
