# North American Ecosystem

A local, offline Godot 4 wildlife observation simulation. GitHub repository name: **AutoEcosystem**.

## Run

Double-click `Launch.cmd` on Windows (finds Godot on PATH or under your Downloads folder), or open `project.godot` in Godot 4.7.2 and press F5. For another installation location: `./Launch.ps1 -Godot 'path/to/Godot.exe'`. No downloads, assets, accounts, or APIs are needed at runtime. The world starts paused.

Use right mouse + WASD to fly; Q/E descend/ascend, Shift accelerates. Click an animal to inspect it; use the roster to select animals through trees. Follow tracks the selection. Space starts/pauses, period steps one simulation tick. Buttons provide save/load, speed and environmental events. Escape releases the mouse.

F follows, R focuses and Tab cycles animals. Click the habitat map to explore. Resource markers reveal meadows and drinking sites. Sound/labels/markers are optional and their preferences persist locally. Recover backup restores the previous checkpoint paused.

New worlds have three wolves and six deer with individual needs, traits and resource/danger memories. Wolves coordinate nearby hunts and share meals; deer flee, rest, graze and drink. Spatial food/water depletion and weather affect survival. This remains an evolving game under active development; see ROADMAP.md for tested scope and remaining limitations.

To create a portable local Windows build including Godot, run `./tools/build_portable.ps1 -Godot 'path/to/Godot.exe'`, then open `builds/Windows/Play.cmd`. Generated binaries remain outside Git. Godot and component notices are included in the bundle; see [Godot licensing](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).

## Development attribution

Project direction, product scope, and key design decisions were made by me. AI tools, including OpenAI Codex, assisted with implementation, coding, debugging, and development workflows.

See ROADMAP.md, HOW_IT_WORKS.md, GITHUB_SETUP.md and ASSET_LICENSES.md. No software license has been selected.
