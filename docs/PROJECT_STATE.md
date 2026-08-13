# Project

Wakaremichi / まいにちの分かれ道

# Current Phase

v1.0 Release Candidate

# Git Review State

Latest reviewed implementation/config commit:
`a03c0c36d5c95b113c316a4c4c26948582859f14`

State Snapshot base:
`b0358572e0c7aecf01aef0a0210e4dd9b786cc68`

Review target: this work unit's new implementation commit

Latest reviewed implementation/config status: APPROVED

- ChatGPT exact SHA code review: PASS
- Gameplay Visibility Fix code review: PASS
- Gameplay Visibility Fix new Human physical-device QA: PASS
- Unit Tests: 99 PASS / FAIL 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- `git diff --check`: PASS

Current work unit: v1.0 Privacy Manifest + UMP Privacy Options + Hide Remove-Ads

Current work unit status: IMPLEMENTED / VALIDATION PASS / REVIEW PENDING

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
- App-owned Privacy Manifest
- UMP privacy-options re-entry
- v1.0 remove-ads purchase UI hiding

# v1.0 Privacy Release Requirements

IMPLEMENTED / VALIDATION PASS / REVIEW PENDING

- The app-owned `PrivacyInfo.xcprivacy` declares only `NSPrivacyAccessedAPICategoryUserDefaults` with approved reason `CA92.1` for app-only `@AppStorage` / `UserDefaults` use.
- No app-owned file timestamp, system boot time, disk space, or active-keyboard category was found or declared.
- The manifest is an app-target resource and is present at the root of the built app bundle.
- Collection is the stable privacy/settings surface. Its privacy-options entry point is visible only while UMP reports `.required`; `.notRequired` and `.unknown` remain hidden.
- The privacy-options form uses UMP's current `presentPrivacyOptionsForm` path. Presentation errors are handled without a crash, and the existing launch consent / `canRequestAds` / Rewarded gating semantics are unchanged.
- Human StoreKit decision B is implemented: the v1.0 remove-ads purchase CTA is hidden.
- `com.karemichi.removeads`, `StoreManager`, purchase/restore infrastructure, and purchased-entitlement effects remain intact for a future release and existing entitled users.
- SwiftData schema is unchanged.

Validation:

- Unit Tests: 99 PASS / FAIL 0 / SKIP 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned clean build: PASS
- Built-product privacy manifest validation: PASS
- Privacy-options / Collection visual render QA: PASS
- Final approval: not recorded; exact-SHA review is pending

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

Approval history:

- Implementation `f6a35a3239a9fc307a835a60ff4c2bb24f598cbd` passed code review.
- Initial Human QA was reported PASS and receipt `69563123adfe7f39e2a3e56e2716789578b81871` recorded approval.
- Subsequent physical-device screenshot evidence reproduced clipping at the bottom SpriteView/HUD boundary.
- The previous Final Approval is REVOKED / superseded. Its historical receipt remains in `docs/REVIEW_LOG.md`.
- Review Fix `0351d6b2d31a465ae8f45ad2aaa5486964300ddf` passed automated validation but exact-SHA review found an ancestor coordinate-space traversal defect.
- Code Fix `a03c0c36d5c95b113c316a4c4c26948582859f14` corrected that traversal, passed exact-SHA review, and passed the new Human physical-device QA.

Confirmed causes:

- The former world-flush camera clamp left no protected context margin at the walkable perimeter.
- SpriteKit viewport changes did not immediately reclamp the camera or rebuild the vignette.
- Three coordinate-selected source textures per cell kind reduced instant floor/wall recognition.

Implemented:

- Added a tile-relative screen-space `gameplaySafeRect` inside the actual visible `SKView` bounds.
- Camera resolution protects the complete player sprite, about one tile of meaningful path context, and the complete nearby explored goal at its maximum pulse scale.
- Controlled outside-world reveal is capped at two tiles; player/context safety has priority when optional goal protection cannot fit.
- Initial placement, movement, warp, restart, and resize all use one `resolvedCameraPosition` path.
- `didChangeSize(_:)`, measured SwiftUI `SpriteView` size, and ancestor-clipped visible bounds immediately reclamp the camera and resize the vignette.
- Player is built before the initial camera so the first solve uses the actual sprite frame.
- `MazePlayView` now keeps viewport measurement separate from layout, and clips the HUD texture to its fixed 112pt allocation so it cannot cover SpriteKit content.
- Fixed `actualVisibleViewportRect` ancestor traversal so each intermediate rectangle remains in its owning ancestor coordinate space; conversion back to `SKView` occurs once after traversal.
- Ancestor intersection now applies only to clipping/masking ancestors and the root window, so non-clipping SwiftUI/UIKit containers do not shrink the viewport.
- Floor cells always use `MazeFloor`; wall cells always use `MazeWall`.
- Coordinate cropping remains within those two source textures; variant assets remain available for rollback.
- Maze generation, topology, collision, movement, Fog of War, HUD semantics, persistence, ads, audio, and identifiers are unchanged.

Validation:

- Unit Tests: 90 PASS / FAIL 0 (88 existing plus 2 coordinate-traversal regression tests)
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned clean build: PASS
- Codex Visual QA: PASS on 320x568 and 390x844 layouts
- Actual `MazeScene` + `SKView` projection assertions cover player/context at edges and corners, visible goal maximum pulse, resize, warp, and restart.
- Independent nested-clipping and non-clipping ancestor fixtures validate visible/safe rectangles without using the runtime helper to produce expected values.
- Camera matrix: center, four edges, and four corners rendered and inspected.
- Bottom/right goal approach: traveler, goal flag, adjacent floor, and walls remain fully visible above the HUD boundary.
- Full `MazePlayView` evidence confirms the 112pt HUD no longer paints over SpriteKit content.
- ChatGPT exact-SHA review: PASS
- New Human physical-device camera QA: PASS
- Human floor/wall readability QA: PASS

Current component status:

- Camera visibility: PASS / APPROVED
- Floor/wall single-texture rendering: PASS / APPROVED
- Floor/wall readability blocker: resolved

Review-fix acceptance status:

- Screen-space `gameplaySafeRect`: IMPLEMENTED / VALIDATION PASS
- Complete player/context and visible-goal projection containment: PASS
- Actual scene/view integration coverage: PASS
- Full `MazePlayView` HUD-boundary evidence: PASS
- Final Human Gate: PASS

Specification: `docs/GAMEPLAY_VISIBILITY_FIX_SPEC.md`

# Release Blockers

- Apple Developer App ID, capabilities, Team, distribution certificate, and provisioning alignment are unverified.
- App Store Connect app record / Bundle ID alignment is unverified.
- AdMob app Bundle ID, app linkage, Rewarded unit, and Privacy & messaging configuration are unverified.
- This Mac currently has no valid code-signing identity; a Wakaremichi signed Archive does not exist.
- App Store validation / upload has not been performed.
- App Store Connect metadata, privacy answers, public privacy/support URLs, submission screenshots, age rating, release method, and territories are incomplete or unverified.

Detailed matrix: `docs/RELEASE_SUBMISSION_READINESS.md`

# Next Work Unit

Exact-SHA review of this privacy implementation, then External Dashboard Alignment + Signed Archive / Validation.

v1.0 Privacy Manifest + UMP Privacy Options + StoreKit Release Decision

Status: NOT STARTED

After that work unit is reviewed, continue with External Dashboard Alignment + Signed Archive/Validation.

# Do Not Start

- New game features during v1.0 release-readiness work
- Banner ads
- Interstitial ads
- App Open ads
- Large-scale refactoring
- StoreKit specification expansion

# Documentation Note

`README.md` and `VALIDATION_REPORT.md` contain historical implementation and validation notes. Where their older status statements conflict with this file, verify the current Git source and tests and treat this file as the current-state index.
