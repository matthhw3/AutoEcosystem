# GitHub setup and commit policy

- Create **PUBLIC** `matthhw3/AutoEcosystem`, connected to this existing project folder. Default branch: `main`.
- Do not initialize a separate remote README, license or ignore file. Preserve local history.
- Authenticate Git for Windows using Git Credential Manager; never put credentials in scripts, remotes, or tracked files.
- Set repository-local `user.name` and `user.email` to the user's confirmed verified GitHub identity. Existing Git configuration matches the connected account name/email, but verification and user confirmation are pending.
- No Codex, Claude, other AI identities, or `Co-authored-by` trailers in commit metadata.
- Include the exact development attribution in README.md.
- Commit each meaningful completed step after relevant tests: setup, terrain, camera, models, individual mechanics, UI, interactions, persistence, testing improvements. Prefer small coherent commits with concise messages. Never squash or rewrite development history. Do not commit planned or untested work as completed.
- Before EVERY push: inspect outgoing diffs and metadata for credentials, personal data, sensitive files, and licenses. Run `tools/check_repository.ps1` in addition to manual review. Flag files above 10 MiB for Git LFS; GitHub rejects ordinary files above 100 MiB. Never upload assets with unclear redistribution rights.
- Godot caches, local saves, credentials and builds are ignored. No software license without discussion.

## Once authenticated

From this folder, initialize `git init -b main` if needed, configure the confirmed author locally, make coherent tested commits, add `origin https://github.com/matthhw3/AutoEcosystem.git`, review safety checks, then `git push -u origin main`. Verify remote visibility is public and its default branch is main. Never force push or overwrite a pre-existing remote history.

Current blocker: GitHub connector supports reading but no repository creation; no local Git transport credential was available during initial inspection. Remote creation/public visibility and push remain unverified until authentication is provided.
