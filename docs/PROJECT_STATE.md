# Project

Wakaremichi / まいにちの分かれ道

# Current Phase

v1.0 Release Candidate

# Git Review State

Latest reviewed implementation/config commit:
`f6a35a3239a9fc307a835a60ff4c2bb24f598cbd`

State Snapshot:
`d451969ce538a9f7ea6165389da32c17f6d0719c`

Review target: none / completed

Latest reviewed implementation/config status: APPROVED

- ChatGPT exact SHA code review: PASS
- Human device QA: PASS
- Unit Tests: 83 PASS / FAIL 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- `git diff --check`: PASS

Current work unit: Gameplay Visibility Fix — Camera Bounds + Single Tile Set

Current work unit status: APPROVED

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
- Gameplay Visibility Fix — Camera Bounds + Single Tile Set

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

APPROVED

Confirmed causes:

- The former world-flush camera clamp left no protected context margin at the walkable perimeter.
- SpriteKit viewport changes did not immediately reclamp the camera or rebuild the vignette.
- Three coordinate-selected source textures per cell kind reduced instant floor/wall recognition.

Implemented:

- Added a pure, testable camera-bounds calculation with one-tile controlled overscan.
- Initial placement, movement, warp, restart, and resize all use the same camera clamp path.
- `didChangeSize(_:)` and the measured SwiftUI `SpriteView` size immediately reclamp the camera and resize the vignette.
- Floor cells always use `MazeFloor`; wall cells always use `MazeWall`.
- Coordinate cropping remains within those two source textures; variant assets remain available for rollback.
- Maze generation, topology, collision, movement, Fog of War, HUD semantics, persistence, ads, audio, and identifiers are unchanged.

Validation:

- Unit Tests: 83 PASS / FAIL 0 (68 existing plus 15 focused visibility tests)
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned clean build: PASS
- First Visual QA: PASS on 320x568 and 390x844 layouts
- Camera matrix: center, four edges, and four corners rendered and inspected
- Bottom-right goal approach: traveler, goal flag, adjacent floor, and walls fully visible in SpriteView evidence
- Full `MazePlayView` evidence confirms header/HUD remain separate from the SpriteKit viewport
- ChatGPT exact SHA code review: PASS
- Human physical-device QA: PASS for center, four edges, four corners, and bottom goal visibility
- Human floor/wall readability QA: PASS

Resolved release blockers:

- Map-edge camera/viewport visibility
- Floor/wall readability

Specification: `docs/GAMEPLAY_VISIBILITY_FIX_SPEC.md`

# Release Blockers

- Apple Developer App ID / Bundle ID alignment verification
- App Store Connect app record / Bundle ID alignment verification
- AdMob app Bundle ID alignment verification
- Signed Archive
- App Store validation / upload
- App Store Connect metadata / privacy / screenshots
- Territory/privacy configuration as applicable
- StoreKit remove-ads exposure/configuration decision

# Next Work Unit

Release External Alignment / Submission Readiness

Status: READY

1. Verify Apple Developer App ID and production Bundle ID alignment.
2. Verify the App Store Connect app record and Bundle ID alignment.
3. Verify the AdMob app Bundle ID alignment.
4. Decide and configure StoreKit remove-ads exposure for submission.
5. Produce a signed Archive and complete App Store validation/upload.
6. Complete metadata, privacy, screenshots, and territory configuration.

# Do Not Start

- New game features during v1.0 release readiness
- Banner ads
- Interstitial ads
- App Open ads
- Large-scale refactoring
- StoreKit specification expansion

# Documentation Note

`README.md` and `VALIDATION_REPORT.md` contain historical implementation and validation notes. Where their older status statements conflict with this file, verify the current Git source and tests and treat this file as the current-state index.
