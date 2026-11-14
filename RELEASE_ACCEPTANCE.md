# Release acceptance contract

The target is a complete first release of the original observation sandbox, not an endless feature backlog. Milestones are checkpoints. The persistent goal remains active until the following criteria have concrete evidence, or a permitted stopping condition applies.

## Required scope

| Area | Acceptance condition | Verification |
| --- | --- | --- |
| Local Windows game | A portable build launches without installing Godot, network access, an account or an API key. Engine/component notices are present. | Build, manifest validation, standalone headless and graphical launch |
| Forest and camera | A cohesive 3D North American forest with recognizable original wolves/deer; camera can fly, focus and follow without ground penetration or exposed broken world edges. | Habitat tests, rendered views and interaction checks |
| Independent agents | At least one wolf and two deer, with biological needs, individual decisions and persistent learned danger/resource memory. Traits meaningfully affect choices. | Behavioral tests and observed scenarios |
| Ecosystem lifecycle | Hunting, fleeing, consuming spatial resources, rest/recovery, reproduction, juvenile development, aging and death operate through normal simulation ticks. No unconditional survival or population replacement. | Natural lifecycle and multi-seed endurance scenarios plus targeted regressions |
| Interventions | Drought, wildfire and flood visibly affect the world and animals. Event progression and effects persist across saves and halt while paused. | Event continuity, escape/exposure and rendered event tests |
| Observation | Selection/follow/focus, roster and map remain usable during pause; inspection clearly shows needs, current behavior and recent experiences. | Input/scene acceptance tests and native interaction checks |
| Time controls | Start is explicit; Pause stops and saves; Step advances exactly one fixed tick; speed schedules the correct ticks. No offline progression on reopen. | Integration and process-level persistence tests |
| Persistence | Simulation, memory, environment and observer state survive save/load. Existing saves migrate safely. Invalid/unwritable files retain current state and show actionable feedback. Closing normally saves; failures keep the application open. | Corruption, migration, save-failure, backup and close/reopen scenarios |
| Usability | Clear onboarding/control help, readable contrast, usable minimum 1152x720 layout, keyboard controls, and retained observation/audio preferences. Destructive reset is confirmed and recoverable. | Screenshots, focus/input tests and native checks |
| Stability/performance | All required test suites pass. Multiple seeded endurance runs show finite valid bounded state and explain ecological outcomes. Normal/stress graphical benchmarks on RTX5070 target at least60 average fps after warmup, with frame timing reported honestly. | Recorded test/benchmark logs; no script/runtime errors |
| Provenance and Git | Original/provenanced assets only; no project software license added. Small tested commits under the verified user identity; no AI coauthors or rewritten history; safety review before every push. | Asset ledger, scan, metadata/remote checks |

## Modeling choices

An original stylized procedural art style is acceptable; photorealism and imported assets are not required. Learned avoidance/resource recall is the persistent learning layer; no LLM or neural network is required. Genetic inheritance, simulated fluid dynamics, detailed gestation and additional species are outside the original release contract. Their absence must be documented rather than disguised as implemented realism.

## Completion rule

Record evidence and remaining failures in RELEASE_AUDIT.md and ROADMAP.md. Resolve actual acceptance failures, rebuild the final distribution, rerun affected checks and verify pushed checkpoints. Do not mark the persistent goal complete just because a prototype is playable, a milestone ended, or a narrow suite passes. Do not invent new mandatory scope after this contract is satisfied.
