# Project

Wakaremichi / まいにちの分かれ道

# Current Phase

v1.0 Release Candidate

# Git Review State

Latest reviewed implementation/config commit:
`135b101b94704bfa8cdc6911227ef8a5db8cf35a`

State Snapshot:
`8ce815b954034d6cbd290715677d8203b578c54a`

Review target: Gameplay Visibility Fix specification-sync commit produced by this work unit

Latest reviewed implementation/config status: APPROVED

- ChatGPT exact SHA code review: PASS
- Human device QA: PASS
- Unit Tests: 68 PASS / FAIL 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- `git diff --check`: PASS

Current work unit: Gameplay Visibility Fix — Camera Bounds + Single Tile Set

Current work unit status: SPEC READY / IMPLEMENTATION NOT STARTED

Continuity: Ready

# Completed

- Daily streak
- Deterministic collectibles
- Spoiler-free result sharing
- Google Mobile Ads SDK integration
- UMP consent flow
- Rewarded ads
- SKAdNetwork official list
- Exploration UI polish
- Footstep volume restoration
- Production App Icon integration
- Result Rewarded Ads + Replay

# Result Rewarded Ads + Replay

APPROVED

- The official Daily completion is saved before the Result Gate ad flow.
- A ready Rewarded ad presents before Result; reward transitions to Result.
- Unavailable, consent-blocked, SDK, and presentation failures fail open to Result.
- Cancellation before reward returns to the gate with an explicit Result fallback.
- Replay starts only after reward and uses the same day, seed, and maze.
- Replay uses memory-only `RunSessionMode.replay`; the SwiftData schema is unchanged.
- Replay does not mutate the official `DailyRun`, completion, streaks, total completed days, keepsake/collection, first diagnosis, or saved official axes/result.
- `RewardedGateState` and `RewardedAdSession` prevent duplicate Result transitions and Replay starts.
- Result/Replay use a ready-only ad path; existing Continue/Restart load-waiting behavior remains unchanged.

Latest validation:

- Unit Tests: 68 PASS (existing 63 plus 5 review-fix tests)
- Debug Build: PASS
- Release Generic iOS Device Build: PASS
- Google official test Rewarded presentation: PASS
- Result Gate reward, cancellation/fallback, and Result transition: PASS
- Dismissal reload: PASS
- Replay CTA, reward, same-day/same-seed maze, gameplay reset, and transient result: PASS

# Repository

GitHub: <https://github.com/NAOKI-Ko/wakaremichi-ios>

Visibility: Public (intentional)

Branch: `main`

# Local Release Identity

- Production Bundle Identifier: `com.naoki.wakaremichi`
- Test Bundle Identifier: `com.naoki.wakaremichi.tests`
- Local Xcode identity status: configured
- Bundle ID blocker: resolved
- External Apple Developer, App Store Connect, and AdMob dashboard status: not changed or verified by this work unit

# App Icon

Integrated and APPROVED

- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- Home Screen Visual QA: PASS
- Source: 1024x1024 PNG, opaque, no alpha
- No white margin, double-rounded corners, or unintended crop
- Traveler and lantern readability confirmed at small size

# Gameplay Visibility Fix

SPEC READY / IMPLEMENTATION NOT STARTED

Release-blocking user QA findings:

- Map-edge camera/viewport behavior can push the player, nearby path, or goal outside the useful visible area.
- Multiple floor/wall source textures reduce immediate passable/impassable recognition.

Approved specification direction:

- Use a viewport-aware camera clamp across the center, four edges, and four corners.
- Recalculate camera bounds when the SpriteKit viewport changes and validate the complete SwiftUI/SpriteKit crop.
- Use `MazeFloor` as the single floor texture and `MazeWall` as the single wall texture for v1.0.
- Keep unused variant assets for rollback; do not change maze generation, Fog of War, topology, collision, or gameplay rules.

Specification: `docs/GAMEPLAY_VISIBILITY_FIX_SPEC.md`

# Release Blockers

- Map-edge camera/viewport visibility bug
- Floor/wall texture readability issue
- Apple Developer App ID / Bundle ID alignment verification
- App Store Connect app record / Bundle ID alignment verification
- AdMob app Bundle ID alignment verification
- Signed Archive
- App Store validation / upload
- App Store Connect metadata / privacy / screenshots
- Territory/privacy configuration as applicable
- StoreKit remove-ads exposure/configuration decision

# Next Work Unit

Gameplay Visibility Fix Implementation

Status: SPEC READY / IMPLEMENTATION NOT STARTED

1. Implement viewport-aware camera bounds and size-change handling.
2. Fix gameplay rendering to the `MazeFloor` / `MazeWall` single tile set.
3. Run focused/full tests and Debug/Release builds.
4. Complete small/standard iPhone visual QA at the center, four edges, and four corners.
5. Complete Human Gate and exact SHA review.

# Do Not Start

- New game features outside the active Gameplay Visibility Fix work unit
- Banner ads
- Interstitial ads
- App Open ads
- Large-scale refactoring
- StoreKit specification expansion

# Documentation Note

`README.md` and `VALIDATION_REPORT.md` contain historical implementation and validation notes. Where their older status statements conflict with this file, verify the current Git source and tests and treat this file as the current-state index.
