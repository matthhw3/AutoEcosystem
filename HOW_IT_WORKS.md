# Architecture and decisions

Godot 4.7.2 / GDScript, compatibility renderer for reliable startup. Procedural low-poly forest prioritizes readable animal behavior. The renderer can be upgraded after profiling; no dependency on an online service.

`scripts/simulation.gd` owns serializable agent state and seeded randomness independently of the scene tree. Fixed 0.1-second ticks run only after Start or explicit Step. Biological needs feed individual behavior choices, while danger and recent experiences persist across ticks/saves. Time scaling schedules extra fixed ticks; camera and UI stay interactive while paused.

`scripts/forest.gd` builds procedural scenery and supplies terrain height. `scripts/spectator_camera.gd` owns free flight/follow. `scripts/main.gd` integrates model, animal visual proxies, UI, picking and persistence. Views never advance agent biology.

`scripts/animal_visual.gd` is a replaceable view with a procedural species silhouette and simulation-time poses. Walking/sprinting legs, grazing head tilt, resting posture, death pose and selected labels freeze when biological time pauses. Forest event views use static cues with no independent timer; changing events while paused changes the chosen intervention but advances no time.

The three behavior layers are deliberately inspectable: needs (hunger/energy/stamina), prioritized local decisions (hazards/perceived predators, fatigue, food, wandering), and a bounded memory of danger and experiences. Remembered danger biases later travel. This is lightweight learned avoidance, not a neural model. Deer mature at 365 days and wolves at 730 days; both parents require maturity and healthy needs. Biological aging uses 1200 simulation seconds per day. Population is bounded to 36 total records in this prototype, including dead animals retained for inspection.

Environmental interventions are simplified: drought lowers global forage; wildfire damages animals near the clearing and prompts escape; flood prompts evacuation and lowers forage. Static meshes indicate event areas. Restoring normal weather removes the visual effect and allows forage recovery. The model does not simulate fire spread, fluid dynamics or individual plants.

Save schema is versioned and JSON based. Random state is stored as a string to preserve 64-bit precision. Save on pause and normal window close; load and launch always pause. No wall clock advancement. Autosave uses a temporary file and backup. Invalid saves must leave the current simulation intact.

Save JSON uses full precision; the parser can still round a double by one ULP. Seeded execution is repeatable, while restored floating values are tested within 1e-12, not promised bit-identical replay. Save errors keep the window open on normal close. Saves live under Godot's `user://` directory (normally `%APPDATA%/Godot/app_userdata/North American Ecosystem`); tests redirect APPDATA to ignored `.local/` and restore any prior test saves.

Validation: `tools/run_tests.ps1 -Godot <console executable>` runs biological and scene integration tests. Integration covers paused startup, start/step, pause autosave, load paused, state restoration and malformed-save rejection. `-- --capture` runs a graphical viewport capture to ignored test-results/observatory.png; `-- --smoke` starts the full scene, steps and exits. Windows sandbox certificate-store warnings are unrelated to runtime networking (the game uses none).

Expanded QA runs 36,000 ticks representing one simulation hour and checks finite values, bounds, needs, population and save validity every minute. Tests also cover juvenile fertility rejection, exact maturity thresholds, restored fear steering, fatigue recovery, old age, wildfire fatalities and hazard escape. Scene QA verifies roster selection, camera focus/follow and event-view toggling without time progression. Graphical captures on RTX 5070 verify normal, wildfire and flood presentation. These checks do not replace human playtesting or FPS profiling.

Runtime assets are replaceable visual proxies. Simulation knows species and position, not mesh structure. Future models can replace proxies without changing biological state. Current perception is distance based and terrain movement is height projected; line-of-sight, navigation around obstacles and pack cooperation remain future work.

Research: Godot official documentation on command-line headless execution, saving games and RandomNumberGenerator state informed the testing/persistence design. See https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html and https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html.
