# Project

Wakaremichi / まいにちの分かれ道

# Current Phase

v1.0 Release Candidate

# Git Review State

Latest reviewed implementation/config commit:
`135b101b94704bfa8cdc6911227ef8a5db8cf35a`

State Snapshot:
`bfcd2a8c45d39ea0ac935696474fec144e67f700`

Review target: none (completed)

Latest reviewed implementation/config status: APPROVED

- ChatGPT exact SHA code review: PASS
- Human device QA: PASS
- Unit Tests: 68 PASS / FAIL 0
- Debug Simulator clean build: PASS
- Release Generic iOS Device unsigned build: PASS
- `git diff --check`: PASS

Current work unit: Release External Alignment / Submission Readiness

Current work unit status: NOT STARTED

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

1. Verify Apple Developer App ID and Bundle ID alignment.
2. Verify the App Store Connect app record and AdMob Bundle ID alignment.
3. Complete a signed Archive, validation, and upload.
4. Complete App Store Connect metadata, privacy, screenshots, and applicable territory settings.
5. Decide StoreKit remove-ads exposure/configuration for release.

# Do Not Start

- New game features outside the approved Result Rewarded Ads + Replay work unit
- Banner ads
- Interstitial ads
- App Open ads
- Large-scale refactoring
- StoreKit specification expansion

# Documentation Note

`README.md` and `VALIDATION_REPORT.md` contain historical implementation and validation notes. Where their older status statements conflict with this file, verify the current Git source and tests and treat this file as the current-state index.
