# Review Log

## 2026-08-09 — Final Review Receipt

Implementation Commit:
`55d7c0d8857989b248458a96c16e0d10ebcfe9d2`

Commit:
`refine exploration layout and restore footsteps`

Decision: PASS

- Code Review: PASS
- Visual QA: PASS
- Audio QA: PASS
- Tests: 53 PASS
- Debug: BUILD SUCCEEDED
- Release: BUILD SUCCEEDED

Reviewed scope:

- `KareMichi/GameView.swift`
- `KareMichi/MazeScene.swift`
- `KareMichi/Audio/sfx_footstep_a.wav`
- `KareMichi/Audio/sfx_footstep_b.wav`
- `KareMichi/Audio/sfx_footstep_c.wav`

Notes:

- Repository Public is the intentional setting.
- No issue was found in source or game logic within the reviewed scope.
- The next work unit is Release Identity.

## 2026-08-09 — Release Identity Final Review Receipt

Implementation/Config Commit:
`04d24a8b885543202b29d9ebb78e6e0ea9263cfb`

Commit:
`chore: set production app identity`

Decision: PASS

Reviewed scope:

- `KareMichi.xcodeproj/project.pbxproj`
- `docs/START_HERE.md`
- `docs/PROJECT_STATE.md`

Validation:

- Tests: 53 PASS
- Debug Build: PASS
- Release Build: PASS (`CODE_SIGNING_ALLOWED=NO`)

Notes:

- Production Bundle ID: `com.naoki.wakaremichi`
- Test Bundle ID: `com.naoki.wakaremichi.tests`
- External Apple Developer, App Store Connect, and AdMob dashboards are not yet verified.
- The next work unit is App Icon Integration.

## 2026-08-10 — App Icon Final Review Receipt

Implementation/Config Commit:
`e7bfbb4b92ba5c196bb1782fd883f2f125310a6e`

Commit:
`chore: integrate production app icon`

Decision: PASS / APPROVED

- ChatGPT exact SHA Review: PASS
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- Home Screen Visual QA: PASS
- `origin/main` exact SHA: confirmed
- Working tree clean: confirmed

Reviewed scope:

- `KareMichi.xcodeproj/project.pbxproj`
- `KareMichi/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- `KareMichi/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `docs/PROJECT_STATE.md`

App Icon validation:

- 1024x1024 PNG
- Opaque, with no alpha channel
- No white margin or baked/double-rounded corners
- No unintended crop
- Traveler and lantern readability confirmed at small size

Notes:

- The App Icon integration blocker is resolved.
- The next work unit is Result Rewarded Ads + Replay.

## 2026-08-12 — Result Rewarded Ads + Replay Final Review Receipt

Work Unit:
`Result Rewarded Ads + Replay`

Initial Implementation:
`2f59deb000acbd9a0b30fb56da602233ccb099cf`

Initial Review: FIX REQUIRED

Reason:

- When Rewarded was not loaded, the Result Gate could wait for ad loading to finish.

Review Fix:
`135b101b94704bfa8cdc6911227ef8a5db8cf35a`

Fix:

- Added the ready-only Result/Replay ad path `showRewardedAdIfReady`.
- An unready ad now returns an immediate unavailable outcome.
- Result fails open without waiting; Replay stays on the Result screen.

Re-review:

- ChatGPT exact SHA Code Review: PASS
- Human Device QA: PASS

Final Decision: PASS / FINAL APPROVED

Validation:

- Unit Tests: 68 PASS / FAIL 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- `git diff --check`: PASS

Human QA:

- Google official test Rewarded presentation: PASS
- Result Gate Rewarded flow: PASS
- Result transition after reward: PASS
- Cancellation before reward and Result fallback: PASS
- Next Rewarded reload after dismissal: PASS
- Result-screen Replay CTA: PASS
- Replay start after reward: PASS
- Same day, seed, and maze: PASS
- Replay gameplay reset: PASS
- Replay Result presentation: PASS

Approved behavior:

- Official Daily completion is saved before advertising.
- Result fails open when an ad is unavailable, consent-blocked, or cannot be presented.
- Replay starts only after reward and remains memory-only through `RunSessionMode.replay`.
- Replay does not modify the official `DailyRun`, completion, streaks, completed-day count, keepsake/collection, first official diagnosis, or saved official axes/result.
- The SwiftData schema is unchanged.
- `RewardedGateState` and `RewardedAdSession` preserve exactly-once Result and Replay transitions.

Notes:

- The Result Rewarded Ads + Replay release blocker is resolved.
- The next work unit is Release External Alignment / Submission Readiness.

## 2026-08-12 — Gameplay Visibility Fix Final Review Receipt

Work Unit:
`Gameplay Visibility Fix — Camera Bounds + Single Tile Set`

Specification Sync:
`d451969ce538a9f7ea6165389da32c17f6d0719c`

Final Implementation:
`f6a35a3239a9fc307a835a60ff4c2bb24f598cbd`

Final Decision: PASS / FINAL APPROVED

- ChatGPT exact SHA Code Review: PASS
- Codex Visual QA: PASS
- Human Physical-Device QA: PASS
- Unit Tests: 83 PASS / FAIL 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- `git diff --check`: PASS

Approved camera behavior:

- Pure, testable `MazeCameraGeometry` uses the runtime viewport and one-tile controlled overscan without zooming out.
- Initial placement, movement, warp, restart, and resize share one clamp path.
- `didChangeSize(_:)` reclamps the camera, while SwiftUI supplies the measured `SpriteView` size.
- Viewport changes rebuild and resize the vignette.
- Human QA passed at the center, four edges, four corners, and bottom goal approach.

Approved tile behavior:

- Floor cells use `MazeFloor`; wall cells use `MazeWall`.
- A/B variants and chunk/hash source selection are not used during gameplay.
- Coordinate cropping and existing tint remain within the two approved source textures.
- Variant assets remain available for rollback.
- Human QA confirmed immediate floor/wall recognition without distracting from gameplay objects.

Non-regression:

- Maze generation, daily seed, topology, collision, movement, auto slide, Fog of War, stamina, treasure, warp semantics, and goal coordinates are unchanged.
- DailyRun, streak, collection, diagnosis, Result, Replay, Rewarded ads, audio, haptics, SwiftData schema, Bundle ID, App Icon, AdMob, StoreKit, Version, and Build are unchanged.

Resolved blockers:

- Map-edge camera/viewport visibility
- Floor/wall readability

Notes:

- The Gameplay Visibility Fix is final-approved.
- The next work unit is Release External Alignment / Submission Readiness.

## 2026-08-12 — Gameplay Visibility Fix Correction / Approval Revocation

Prior Final Review Receipt Commit:
`69563123adfe7f39e2a3e56e2716789578b81871`

Implementation under review:
`f6a35a3239a9fc307a835a60ff4c2bb24f598cbd`

Correction:

- Subsequent physical-device screenshot evidence contradicted the previous visual conclusion.
- Maze cells near the bottom remain clipped at the SpriteView/HUD boundary.
- The camera visibility acceptance criteria are not met.
- The prior Final Approval is superseded / REVOKED; its receipt above remains unchanged as audit history.

Current decision:

- Code review of `f6a35a3…`: PASS
- Floor/wall single-texture rendering: PASS / retained
- Camera visibility: FIX REQUIRED
- Map-edge / SpriteView boundary clipping blocker: reopened
- Current valid latest reviewed implementation/config: `135b101b94704bfa8cdc6911227ef8a5db8cf35a`

Required correction:

- Define a gameplay safe frame in the actual visible SpriteView coordinate space.
- Validate complete projected player and nearby-goal sprite frames rather than tile centers or camera bounds alone.
- Add actual MazeScene/SKView integration assertions and new full `MazePlayView` evidence showing the HUD boundary.

Status:

- Review Fix specification: ready
- Review Fix implementation: pending
- Final Approval: not restored
