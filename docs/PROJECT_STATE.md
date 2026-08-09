# Project

Wakaremichi / まいにちの分かれ道

# Current Phase

v1.0 Release Candidate

# Git Review State

Latest reviewed implementation/config commit:
`e7bfbb4b92ba5c196bb1782fd883f2f125310a6e`

State Snapshot:
`bfcd2a8c45d39ea0ac935696474fec144e67f700`

Review target: Result Rewarded Ads + Replay implementation commit produced by this work unit

Latest reviewed implementation/config status: APPROVED

- Code/config review: PASS
- Unit Tests: 53 PASS
- Debug Build: PASS
- Release Generic iOS Device Build: PASS (`CODE_SIGNING_ALLOWED=NO`)

Current work unit: Result Rewarded Ads + Replay

Current work unit review status: NOT REVIEWED

Current work unit implementation status: IMPLEMENTED / VALIDATION PASS / REVIEW PENDING

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

# Implemented, Review Pending

- Rewarded Result Gate after an official goal completion
- Result Gate fail-open for unavailable, load, consent, SDK, and presentation failures
- Explicit fallback to the saved result after an unrewarded ad cancellation
- Reward-gated replay from ResultView
- Memory-only replay using the official DailyRun date and seed
- Replay persistence boundary protecting DailyRun, streak, collectibles, and first diagnosis
- Exactly-once result/replay transitions

Latest validation:

- Unit Tests: 63 PASS (existing 53 plus 10 focused tests)
- Debug Build: PASS
- Release Generic iOS Device Build: PASS
- First Visual QA: PASS at 320x568pt for Result Gate and ResultView replay action
- Google test ad presentation: pending device/simulator network-dependent manual confirmation

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

- Result Rewarded Ads + Replay exact-SHA review is pending.
- Apple Developer Bundle ID alignment has not been verified.
- App Store Connect Bundle ID alignment has not been verified.
- AdMob Bundle ID alignment has not been verified.
- A signed Archive and validation have not been performed.
- App Store Connect submission information is incomplete.

# Next Work Unit

Result Rewarded Ads + Replay Review Gate

Status: READY FOR REVIEW

Specification: `docs/RESULT_REWARDED_ADS_REPLAY_SPEC.md`

1. Review the exact implementation commit produced by this work unit.
2. Confirm Google official test-ad presentation, reward, cancellation, and dismissal reload when the network environment permits.
3. Verify the Replay start and Replay result flow on a physical device.

# Do Not Start

- New game features outside the approved Result Rewarded Ads + Replay work unit
- Banner ads
- Interstitial ads
- App Open ads
- Large-scale refactoring
- StoreKit specification expansion

# Documentation Note

`README.md` and `VALIDATION_REPORT.md` contain historical implementation and validation notes. Where their older status statements conflict with this file, verify the current Git source and tests and treat this file as the current-state index.
