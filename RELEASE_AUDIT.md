# Independent release audit

This audit checks concrete failure cases against the original local wildlife-observation vision. It does not equate passing smoke tests with a polished finished game. Audit date: 2026-11-13.

## Reproduced defects and verification

| Finding | Initial evidence | Resolution evidence |
| --- | --- | --- |
| A corrupt primary checkpoint could overwrite the last valid backup on the next normal save/close. | File-based regression created two valid checkpoints, corrupted the primary, restarted the scene, and invoked the same save operation used by normal close. The backup then failed simulation validation. | Lead changed startup recovery and save backup handling. The regression now recovers the valid previous session paused, retains a valid backup, and preserves damaged bytes separately as `.corrupt`. |
| A restored low follow orbit could leave the observer below the terrain. | Public camera pose/follow restoration with a below-ground offset remained below ground after the camera update. The same offset range was possible through upward orbit math. | Lead added constraints to follow, restore, focus and free flight. The regression now remains above terrain. Physical mouse capture was deliberately not used because the user may be playing. |
| Rebuilding into an existing portable directory could retain files outside the manifest. | Builder code overwrote selected files but did not reject other existing files. Manifest hashes alone did not prove folder contents were safe to distribute. | Builder now assembles a new staging folder and archives the previous bundle outside the distribution. A generated DO_NOT_SHIP.fixture was placed in the old bundle; after rebuilding it was absent from the distribution. The final file count exactly matched the manifest plus MANIFEST.json. |

The dedicated `tests/test_release_audit.gd` passed with zero failures after the checkpoint/camera fixes. It preserves existing checkpoint/settings/diagnostic files if accidentally invoked against an existing user directory. Run it with a separate APPDATA directory for isolation.

## Additional observer checks

- A large retained-death roster remains scrollable across periodic refreshes.
- Updating needs preserves the inspection panel's scrolled recent-experience view.
- Invalid startup recovery never starts the simulation or invents offline elapsed time.
- The audit never takes control of the native game window.

## Requirement review

| Original requirement | Evidence available | Remaining qualification |
| --- | --- | --- |
| Independent wolf/deer needs, behavior, memory and learning | Pure simulation state, separate per-animal traits/resource memories/danger recall, biological and integration regression suites. | Long-horizon ecological/lifecycle audit is being run independently; do not promise indefinite coexistence. |
| Start, pause, step, speed; no offline progression | Model has no wall-clock progression; integration verifies paused frames and fixed ticks; corrupt-primary restart test verifies exact prior elapsed state. | Native normal-close and extended hands-on coverage should accompany automated tests. |
| Selection, follow, profiles and experiences | Scene integration plus this audit's follow clearance and scrolling cases. | Presentation/terrain-edge review is in progress separately. |
| Save/load and recoverability | Validated model and observer schema; failure fixtures; new corruption/restart regression. | Power-loss durability is not established by successful rename alone. |
| Locally runnable Windows build | Explicit source selection, bundled Godot engine, generated engine/component notices, SHA-256 manifest; prior smoke/graphical runs documented by lead. Fresh-stage packaging and stale-file regression pass. | Rebuild and revalidate after final source changes. |
| Free tools and asset rights | Current runtime code uses procedural geometry/audio and no external API client. Asset provenance documents original content and the bundled engine's separate notices. | New imports still require source/license review before commit. No project software license has been selected. |

These findings distinguish a verified functional implementation from release quality. Broad hardware coverage, extended hands-on assessment and subjective sound/art quality cannot be inferred from a short headless run.
