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

## 2026-08-13 — Gameplay Visibility Review Fix Final Review Receipt

Work Unit:
`Gameplay Visibility Fix — Review Fix`

Audit timeline:

1. Initial implementation `f6a35a3239a9fc307a835a60ff4c2bb24f598cbd`
2. ChatGPT exact-SHA code review: PASS
3. Initial Human physical-device QA: PASS reported
4. Initial receipt `69563123adfe7f39e2a3e56e2716789578b81871`
5. Subsequent physical-device evidence reproduced bottom-boundary clipping
6. Previous approval: REVOKED / superseded
7. Review Fix specification `b166a73bf0d56bab082aefc0edaf4e483cfc13fd`
8. Review Fix implementation `0351d6b2d31a465ae8f45ad2aaa5486964300ddf`
9. ChatGPT exact-SHA review: FIX REQUIRED because ancestor coordinate-space traversal was incorrect
10. Code Fix `a03c0c36d5c95b113c316a4c4c26948582859f14`
11. ChatGPT exact-SHA review: PASS
12. New Human physical-device QA: PASS
13. Final decision: FINAL APPROVED

Final Implementation:
`a03c0c36d5c95b113c316a4c4c26948582859f14`

Commit:
`fix: correct visible viewport coordinate traversal`

Decision: FINAL APPROVED

Validation:

- Unit Tests: 90 PASS / FAIL 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- `git diff --check`: PASS

Codex Visual QA:

- Small viewport: PASS
- Standard viewport: PASS
- Bottom: PASS
- Bottom goal: PASS
- Top: PASS
- Left/right: PASS
- Four corners: PASS
- Full `MazePlayView` + 112pt HUD boundary: PASS

Human physical-device QA: PASS

Human-confirmed scope:

- Bottom edge and bottom goal
- Top and left/right edges
- Four corners
- SpriteView / HUD boundary
- Floor/wall readability
- No excessive outside-world blank

Approved camera design:

- A screen-space `gameplaySafeRect` uses the actual visible `SpriteView` / `SKView` bounds.
- Complete projected player bounds, meaningful nearby path context, and the complete explored nearby goal bounds are protected.
- GoalFlag protection includes its maximum pulse scale.
- Outside-world reveal remains controlled and tile-relative.
- Initial placement, movement, warp, restart, and resize share one camera solver.
- Ancestor traversal keeps each rectangle in the current parent coordinate space, then converts once back to `SKView` coordinates.
- Clip intersection applies only to `clipsToBounds`, `layer.masksToBounds`, and `UIWindow`; non-clipping ancestors do not shrink the viewport.
- The 112pt HUD is not deducted again as a gameplay safe inset.
- `ExplorationHUD` is clipped to its 112pt allocation; `SpriteView` remains a flexible VStack child and `GeometryReader` remains measurement-only.

Regression coverage:

- Actual `MazeScene` + `SKView` projection assertions
- Edges and four corners
- Visible nearby goal and maximum goal pulse
- Viewport resize, warp, and restart
- Nested clipping and non-clipping ancestors
- Full `MazePlayView` / HUD boundary
- Nested/non-clipping expected rectangles are derived independently from known UIView geometry, not from the runtime helper under test.

Approved tile behavior:

- Floor: `MazeFloor`
- Wall: `MazeWall`
- Floor/wall status: PASS / APPROVED
- `FloorVariantA/B`, `WallVariantA/B`, source variant selection, and chunk/hash source selection are not reintroduced.
- Coordinate cropping remains enabled within the approved single floor/wall textures.

Resolved blockers:

- Map-edge / SpriteView boundary clipping
- Gameplay Visibility Review Fix

Notes:

- Historical initial approval and subsequent revocation entries above remain part of the audit trail.
- The next work unit is `v1.0 Release External Alignment / Submission Readiness`; it is not started by this receipt.

## 2026-08-13 — Privacy / UMP / StoreKit v1 Hide Final Review Receipt

Work Unit:
`Privacy Manifest + UMP Privacy Options + StoreKit v1 Hide`

Audit timeline:

1. Release Readiness Audit `b0358572e0c7aecf01aef0a0210e4dd9b786cc68`
2. Initial privacy implementation `d16f9e12f177317efd62886c8bf090b3d2b4ae99`
3. ChatGPT exact-SHA review: FIX REQUIRED
4. Finding: the purchase CTA was hidden, but the seven-run Collection limit remained and created an unreachable paywall.
5. Review Fix `c7e906a7de34a31432daef9e03abc7d2a66c0b8a`
6. Fix: while the purchase feature is disabled, purchased and unpurchased users both receive unlimited Collection history. The future enabled gate retains unpurchased = 7 and purchased = unlimited.
7. Unit Tests: 104 PASS / FAIL 0 / SKIP 0
8. Debug Simulator clean build: PASS
9. Release Generic iOS Device unsigned build: PASS
10. `git diff --check`: PASS
11. Visual QA: PASS
12. ChatGPT exact-SHA review: PASS
13. Final decision: FINAL APPROVED / LOCAL RELEASE REQUIREMENTS PASS

Final implementation:
`c7e906a7de34a31432daef9e03abc7d2a66c0b8a`

Privacy Manifest status: PASS / APPROVED

- App-owned `PrivacyInfo.xcprivacy` is included at the built-product root.
- It declares only `NSPrivacyAccessedAPICategoryUserDefaults`, with approved reason `CA92.1`.
- App-owned file timestamp, system boot time, disk space, and active keyboard categories are not declared.
- Third-party SDK manifests were not copied into the app-owned manifest.

UMP local implementation status: PASS / APPROVED

- `privacyOptionsRequirementStatus` controls visibility: required is visible; notRequired and unknown are hidden.
- User interaction invokes `presentPrivacyOptionsForm`; presentation failure is safe.
- Launch consent update, `canRequestAds` gating, and Rewarded behavior remain unchanged.
- Required/test-geography physical-device privacy-options form presentation remains a Release QA blocker and is not marked PASS by this receipt.

StoreKit v1 decision: PASS / APPROVED

- Human decision B: the v1.0 remove-ads purchase feature is not public.
- Purchase and restore UI are hidden, and Collection history is unlimited for all v1 users.
- `com.karemichi.removeads`, StoreManager, product loading, purchase/restore, entitlement listeners, ad bypass, and the future Collection limit remain intact.
- App Store Connect remove-ads product configuration and restore UI absence are not v1 blockers while purchase UI remains hidden.

Resolved blockers:

- App-owned Privacy Manifest
- UMP privacy-options local implementation
- StoreKit v1 product decision
- Unreachable seven-run Collection paywall
- Restore UI absence for v1 hidden-purchase scope
- App Store Connect remove-ads product for v1 hidden-purchase scope

Next Work Unit:
`v1.0 External Dashboard Alignment + Signing Readiness`

After that:
`Signed Archive / Validation / Upload`
