# Project

Wakaremichi / まいにちの分かれ道

# Current Phase

v1.0 Release Candidate

# Git Review State

Latest reviewed implementation commit:
`55d7c0d8857989b248458a96c16e0d10ebcfe9d2`

Review target: none

Latest reviewed implementation status: APPROVED

- Code review: PASS
- Visual QA: PASS
- Audio QA: PASS

Current work unit: Release Identity

Current work unit review status: NOT REVIEWED

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

Latest validation:

- Unit Tests: 53 PASS
- Debug Build: PASS
- Release Generic iOS Device Build: PASS

# Repository

GitHub: <https://github.com/NAOKI-Ko/wakaremichi-ios>

Visibility: Public (intentional)

Branch: `main`

# Local Release Identity

- Production Bundle Identifier: `com.naoki.wakaremichi`
- Test Bundle Identifier: `com.naoki.wakaremichi.tests`
- Local Xcode identity status: configured
- External Apple Developer, App Store Connect, and AdMob dashboard status: not changed or verified by this work unit

# Release Blockers

- App Icon integration in the Xcode project is incomplete.
- A signed Archive and validation have not been performed.
- App Store Connect submission information is incomplete.

# Next Work Unit

App Icon and signed release validation

1. Integrate the App Icon.
2. Align the Apple App ID and App Store Connect record with `com.naoki.wakaremichi`.
3. Confirm AdMob app registration alignment with `com.naoki.wakaremichi`.
4. Create and validate a signed Release archive.
5. Complete App Store Connect submission information.

# Do Not Start

- New game features
- Banner ads
- Interstitial ads
- App Open ads
- Large-scale refactoring
- StoreKit specification expansion

# Documentation Note

`README.md` and `VALIDATION_REPORT.md` contain historical implementation and validation notes. Where their older status statements conflict with this file, verify the current Git source and tests and treat this file as the current-state index.
