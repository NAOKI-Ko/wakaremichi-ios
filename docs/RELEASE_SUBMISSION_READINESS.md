# Wakaremichi v1.0 Release Submission Readiness

Audit date: 2026-08-13 (Asia/Tokyo)

State Snapshot base: `b0358572e0c7aecf01aef0a0210e4dd9b786cc68`

Review target: this work unit's new review-fix commit (exact-SHA review pending)

Latest reviewed implementation/config: `a03c0c36d5c95b113c316a4c4c26948582859f14`

## Scope and evidence policy

This is a read-only audit of the Git repository, local Xcode configuration, source, and already-built local artifacts. No Apple Developer, App Store Connect, or AdMob dashboard was opened or changed. Dashboard-only facts are therefore `UNVERIFIED`; this document does not infer them from local configuration.

The only allowed status values in the matrix are `PASS`, `MISSING`, `UNVERIFIED`, `BLOCKED`, and `HUMAN DECISION`.

Official requirement references used for the checklist:

- [Apple: required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple: App privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple: submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Google: UMP SDK for iOS](https://developers.google.com/admob/ios/privacy)

## Executive finding

The reviewed game implementation and unsigned Release build baseline remain intact. The local privacy and v1 StoreKit disposition work is implemented and validated, but this snapshot is not yet ready for a signed archive or App Store submission.

Release-blocking local findings:

1. This Mac currently reports zero valid code-signing identities, and no Wakaremichi signed archive exists.
2. Required App Store metadata, a public privacy-policy URL, a curated submission screenshot set, territory selection, and all external identity/linkage checks remain absent or unverified.
3. The app Privacy Manifest and UMP privacy-options implementation remain locally validated. StoreKit decision B now also removes the unreachable Collection history limit while purchase UI is disabled; the review fix still requires exact-SHA review before approval.

## Readiness matrix

### Local Identity

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| Production Bundle Identifier | Git/Xcode | `com.naoki.wakaremichi` | Matches in Debug and Release | PASS | `project.pbxproj` | Preserve through archive | Engineering |
| Test Bundle Identifier | Git/Xcode | `com.naoki.wakaremichi.tests` | Matches in Debug and Release | PASS | `project.pbxproj` | None | Engineering |
| Version / build | Git/Xcode | `1.0` / `1` | `MARKETING_VERSION = 1.0`; `CURRENT_PROJECT_VERSION = 1` | PASS | `project.pbxproj` | Preserve for v1.0 upload | Engineering |
| Display name | Git/Xcode | `まいにちの分かれ道` | Matches | PASS | `Info.plist`; target build setting | None | Engineering |
| Deployment / device family | Git/Xcode | iOS 17+, iPhone | iOS 17.0; family 1; Catalyst disabled | PASS | `project.pbxproj` | None | Engineering |
| Orientation | Git/Xcode | Portrait | iPhone portrait only | PASS | `Info.plist` | Confirm product intent in final device QA | Product |
| App category hint | Git/Xcode | Games | `public.app-category.games` | PASS | `Info.plist` | Match App Store Connect category | Release Manager |
| App Icon | Git/asset catalog | Production 1024x1024 icon | `AppIcon`, 1024x1024 PNG, opaque/no alpha | PASS | AppIcon asset and reviewed visual QA | Preserve through archive | Design / Engineering |
| App entitlements/capabilities | Git/Xcode | No unplanned capabilities | No entitlement file or target capability entries | PASS | Repository search and `project.pbxproj` | Ensure Apple App ID uses the same capability set | Release Manager |

### Apple Developer

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| App ID exists | Apple Developer | Explicit App ID exists | Dashboard not inspected | UNVERIFIED | No external evidence | Open Certificates, Identifiers & Profiles and verify | Account Holder |
| App ID Bundle ID | Apple Developer | `com.naoki.wakaremichi` | Dashboard not inspected | UNVERIFIED | Local value alone is insufficient | Verify exact match | Account Holder |
| App ID capabilities | Apple Developer + Git | Same as local target | Dashboard not inspected | UNVERIFIED | Local target has no explicit entitlements | Compare capability switches with local target | Account Holder / Engineering |
| Distribution certificate | Apple Developer + local Keychain | Valid Apple Distribution identity | Local Keychain reports 0 valid code-signing identities | BLOCKED | `security find-identity -v -p codesigning` | Install/create a valid distribution identity for the selected team | Account Holder |
| Distribution provisioning | Apple Developer/Xcode | Valid profile or managed signing | Dashboard unverified; local stored profiles did not provide usable audit evidence | UNVERIFIED | Automatic signing is configured | Verify profile generation during signed archive | Account Holder / Engineering |
| Team alignment | Apple Developer/Xcode | Team matches target team `67BCCSD863` | Local team is configured; dashboard membership not inspected | UNVERIFIED | `DEVELOPMENT_TEAM = 67BCCSD863` | Verify account membership and App ID ownership | Account Holder |

### App Store Connect

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| App record | App Store Connect | Wakaremichi iOS app exists | Dashboard not inspected | UNVERIFIED | No external evidence | Verify or create the app record | Account Holder |
| Bundle ID association | App Store Connect | `com.naoki.wakaremichi` | Dashboard not inspected | UNVERIFIED | No external evidence | Verify app record Bundle ID | Account Holder |
| SKU / primary language | App Store Connect | Final values selected | Dashboard not inspected | UNVERIFIED | No external evidence | Confirm SKU and primary language | Product / Account Holder |
| App name | App Store Connect | `まいにちの分かれ道` | Dashboard not inspected | UNVERIFIED | Local display name only | Confirm name availability and exact listing text | Product |
| Version record / build association | App Store Connect | v1.0 record with uploaded build | No Wakaremichi signed archive/upload evidence | BLOCKED | Archive audit below | Complete signing, archive, validation, upload, and build selection | Release Manager |
| Category / age rating | App Store Connect | Final Games category and completed age rating | Dashboard not inspected | UNVERIFIED | Local category hint only | Complete both in App Store Connect | Product |
| Copyright | App Store Connect | Final legal text | Dashboard not inspected; no repository draft | UNVERIFIED | No external evidence | Enter and verify legal owner/year | Account Holder |
| Release method | App Store Connect | Human-selected release method | Dashboard not inspected | UNVERIFIED | No external evidence | Choose manual, automatic, or scheduled release | Product |

### AdMob

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| Google Mobile Ads SDK | Git/SPM | Pinned supported SDK | Google Mobile Ads 13.7.0 | PASS | `Package.resolved` | Preserve for archive | Engineering |
| UMP SDK | Git/SPM | Consent-gated ad requests | UMP 3.1.0 resolved transitively; update/form/`canRequestAds` flow implemented | PASS | `Package.resolved`; `GoogleMobileAdsProvider.swift` | Run consent-region device QA before submission | Engineering / QA |
| Ad format policy | Git/source | Rewarded only | Rewarded only; no banner/interstitial/app-open code | PASS | Provider implementation and repository search | None | Engineering |
| AdMob App ID | Git/Xcode | Production configured once | `ca-app-pub-6219093469517477~7284143930` in Debug/Release | PASS | build settings + `GADApplicationIdentifier` | Verify matching AdMob app record | Engineering |
| Rewarded IDs | Git/Xcode | Google test ID in Debug; production ID in Release | Debug `ca-app-pub-3940256099942544/1712485313`; Release `ca-app-pub-6219093469517477/2031817259` | PASS | build settings | Verify production unit exists and is active | Engineering |
| SKAdNetwork declarations | Git/plist | Reviewed official list | 50 identifiers present | PASS | `Info.plist`; prior reviewed AdMob integration | Recheck at archive time if SDK guidance changes | Engineering |
| AdMob app record / iOS Bundle ID | AdMob | App record linked to `com.naoki.wakaremichi` | Dashboard not inspected | UNVERIFIED | No external evidence | Verify exact Bundle ID and app linkage | Ad Operations |
| Production Rewarded unit | AdMob | ID exists under the correct app | Dashboard not inspected | UNVERIFIED | Local ID alone is insufficient | Verify unit ownership/status | Ad Operations |
| Privacy & messaging configuration | AdMob | Required regional messages published | Dashboard not inspected | UNVERIFIED | UMP code cannot prove dashboard messages | Verify GDPR/US-state messages for selected territories | Privacy / Ad Operations |
| UMP privacy-options re-entry | Git/source + UMP runtime | Visible entry point only when UMP says it is required | Implemented in Collection; `.required` visible, `.notRequired`/`.unknown` hidden; safe form presentation | PASS | `PrivacyOptionsManager`; `CollectionPrivacyOptionsControl`; tests and visual render | Exact-SHA review, then regional device QA | Engineering / Privacy |

### StoreKit

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| Product identifier | Git + App Store Connect | Final non-consumable ID if published | `com.karemichi.removeads`; source comments call it provisional | PASS | `StoreManager.swift` | Do not rename automatically; verify/create exact product if option A is chosen | Product / Engineering |
| Purchase UI exposure | Git/source | Consistent with v1 product decision B | Hidden in v1.0 even after more than seven runs | PASS | `StoreManager.shouldShowRemoveAdsPurchaseCTA`; Collection render test | Preserve until a separately reviewed future release | Product |
| Collection history | Git/source | No unreachable paywall while purchase UI is disabled | Unlimited for purchased and unpurchased users in v1.0 | PASS | `collectionRunLimit`; `collectionRunsForDisplay`; >7-run tests and visual render | Keep release gate and review any future re-enable | Engineering / Product |
| Product-unavailable behavior | Git/source | No crash; no unusable purchase attempt | Product load error leaves product nil and disables purchase button | PASS | `StoreManager.refresh`; disabled button | Add reviewer-facing clarity if purchase remains exposed | Engineering / Product |
| Purchase / entitlement | Git/source | Verified transaction; durable entitlement | StoreKit 2 verification, current entitlements, updates listener | PASS | `StoreManager.swift` | Sandbox-test after product setup | Engineering / QA |
| Restore purchases UI | Git/source | Not exposed while purchase UI is hidden in v1.0 | `restore()` infrastructure retained; no public purchase or restore entry point | PASS | Repository search and StoreManager tests | Add purchase and restore UI together if remove-ads ships later | Engineering |
| Entitlement effects | Git/source | Purchased state removes ad gates; future enabled paywall unlocks records | Ad bypass remains intact; v1 Collection is unlimited for everyone; future enabled gate still distinguishes entitlement | PASS | `GameView`, `ResultView`, `StoreManager`, tests | Sandbox-test all branches before a future StoreKit launch | QA |
| App Store Connect product | App Store Connect | Configured non-consumable if published | Dashboard not inspected | UNVERIFIED | No external evidence | Verify product, price, localization, review screenshot/status | Account Holder / Product |
| v1 remove-ads disposition | Human product decision | B: hide for v1 | Decision B implemented; product ID/infrastructure retained | PASS | Product decision and v1 visibility gate | Do not expose without a separately reviewed work unit | Product Owner |
| Submission with current StoreKit state | App + App Store Connect | No reachable purchase flow or inaccessible history in v1 | Purchase CTA hidden; all Collection history visible; existing ad entitlement effects preserved | PASS | Collection visual QA and release-gate/entitlement tests | App Store Connect product is not a v1 blocker while UI remains hidden | Product / Engineering |

### Privacy

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| App privacy manifest | Git/Apple requirement | App-owned required-reason API use declared | App manifest declares only UserDefaults reason `CA92.1`; built product contains it | PASS | `PrivacyInfo.xcprivacy`; app resource phase; bundle test | Reconfirm in signed archive privacy report | Engineering / Privacy |
| Third-party privacy manifests | Resolved SDK artifacts | Valid manifests embedded with listed SDKs | GoogleMobileAds and UMP Release frameworks each contain `PrivacyInfo.xcprivacy` | PASS | local Release product and SPM artifacts | Reconfirm in signed archive privacy report | Engineering |
| ATT | Git/source/plist | No prompt unless the product intentionally requests tracking permission | No AppTrackingTransparency use or tracking usage description | PASS | repository and plist search | Do not add by inference; reconcile ad configuration with privacy answers | Product / Privacy |
| UMP launch consent gate | Git/source | Update each launch, show required form, gate requests | Implemented; failures do not crash and ads require `canRequestAds` | PASS | `KareMichiApp`; `GoogleMobileAdsProvider` | Complete regional QA and dashboard configuration | QA / Privacy |
| SDK-declared data practices | SDK privacy manifests | Included in App Privacy assessment | Google SDK manifests enumerate advertising/device/product-interaction/location/diagnostic categories, with tracking declared for Device ID by GMA | UNVERIFIED | local SDK manifests | Privacy owner must map actual configuration and all third-party practices into ASC answers | Privacy |
| App Store App Privacy answers | App Store Connect | Complete and accurate, including Google SDK | Dashboard not inspected | UNVERIFIED | No external evidence | Complete and publish responses | Privacy / Account Holder |
| Privacy policy URL | Public web + App Store Connect | Publicly accessible URL | No URL in repository/docs; dashboard not inspected | BLOCKED | Repository search; Apple requires URL for iOS apps | Publish policy and enter URL in App Store Connect | Product / Legal |
| Local persistence | Git/source | Clearly distinguished from off-device collection | SwiftData and AppStorage only; no app-owned cloud/account service found | PASS | imports and repository search | Describe accurately in privacy review | Engineering / Privacy |
| App-owned analytics/accounts | Git/source | No undeclared service | No analytics SDK and no account/login system found | PASS | repository/package search | Recheck archive dependency report | Engineering |
| Sensitive permission APIs | Git/source/plist | No unnecessary permission request | No location, contacts, photos, camera, microphone, health, Bluetooth, calendar, or tracking prompt found | PASS | source and plist search | Confirm on final archive | Engineering / QA |
| Network activity | Git/source/packages | Identified for privacy review | Google ads/UMP and StoreKit communicate externally; gameplay persistence is local | PASS | SDK/package imports and StoreKit source | Reflect actual third-party data practices in policy/ASC | Privacy |

### Signing and Archive

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| Release configuration | Git/Xcode | Optimized Release with product validation | Release uses `-O`, whole-module compilation, `VALIDATE_PRODUCT = YES` | PASS | `project.pbxproj` | None | Engineering |
| Signing style / team | Git/Xcode | Automatic signing with intended team | Automatic; team `67BCCSD863` | PASS | app Debug/Release build settings | Verify external team access | Engineering / Account Holder |
| Shared/usable scheme | Xcode + reviewed validation | `KareMichi` scheme builds Release | Prior unsigned Generic iOS Device build passed; local scheme is discoverable by Xcode state | PASS | `docs/PROJECT_STATE.md`; Xcode scheme state | Confirm Archive action in full-access Xcode | Engineering |
| Required frameworks/packages | Git/SPM | Reproducibly resolvable | Google Mobile Ads 13.7.0 and UMP 3.1.0 are pinned/resolved | PASS | `Package.resolved`; prior Release build | Resolve once before archive and retain lockfile | Engineering |
| Launch configuration | Git/plist | App launches without storyboard dependency | Generated launch screen config and SwiftUI app entry present | PASS | `Info.plist`; `KareMichiApp.swift` | Smoke-test signed archive install | QA |
| Signed archive | Xcode Organizer | Valid distribution-signed v1.0 build 1 archive | No Wakaremichi archive; no valid local code-signing identity | BLOCKED | local Keychain/Archives audit | Restore distribution signing, then Archive | Account Holder / Engineering |
| Archive validation | Xcode Organizer/App Store Connect | Validation succeeds | Not run | BLOCKED | No signed archive | Validate only after all local/external blockers are resolved | Release Manager |

Archive prerequisites, in order:

1. Complete exact-SHA review of the implemented privacy/StoreKit-v1 work unit.
2. Verify Apple Developer App ID, team, capabilities, certificate, and managed provisioning.
3. Verify App Store Connect app record and AdMob app linkage.
4. Complete privacy policy, App Privacy answers, metadata, screenshots, age rating, release method, and territories.
5. Restore a valid Apple Distribution signing identity on the archive Mac.
6. Create a signed Release archive, generate/review its privacy report, validate, upload, and associate the build.

### Metadata, Screenshots, Territory, and Submission

| Item | Source of Truth | Expected | Current | Status | Evidence | Required Action | Owner |
|---|---|---|---|---|---|---|---|
| Description draft | Product docs/App Store Connect | Final localized description | No submission draft found in Git | MISSING | Repository search | Draft, review, and enter description | Product / Marketing |
| Subtitle | Product docs/App Store Connect | Final subtitle if used | No draft found in Git | MISSING | Repository search | Decide and enter or intentionally omit if allowed | Product / Marketing |
| Keywords | Product docs/App Store Connect | Final keywords | No draft found in Git | MISSING | Repository search | Prepare and enter keywords | Marketing |
| Support URL | Public web/App Store Connect | Working public support URL | No URL found in Git | MISSING | Repository search | Publish support page and enter URL | Product |
| Privacy policy URL | Public web/App Store Connect | Working public privacy policy URL | No URL found in Git | MISSING | Repository search | Publish policy and enter URL | Product / Legal |
| Promotional text | Product docs/App Store Connect | Optional, if used | No draft found | MISSING | Repository search | Decide whether to omit or supply | Marketing |
| Marketing assets | Product asset source | Any planned launch assets | No release marketing set identified in Git | MISSING | Repository search | Prepare only if launch plan requires it | Marketing |
| App Store screenshots | App Store Connect | Curated screenshots for every required display size | 27 ignored local QA screenshots exist, but no Git-managed submission set or ASC evidence | MISSING | ignored `Screenshots/` and `Screenshots-Restart/` | Select/capture compliant final screens and upload by required size | Design / Marketing |
| Territory availability | App Store Connect | Human-approved countries/regions | Dashboard not inspected | UNVERIFIED | No external evidence | Select territories and reconcile privacy/UMP obligations | Product / Privacy |
| Pricing / availability | App Store Connect | Final free/paid availability | Dashboard not inspected | UNVERIFIED | No external evidence | Confirm app price and availability dates | Product |
| Submission package | App Store Connect | Build + all required metadata ready | Archive, external alignment, privacy, metadata, and StoreKit decision are incomplete | BLOCKED | This matrix | Clear all blockers before Add for Review | Release Manager |
| Final submission | App Store Connect | Human-authorized submission | Not performed by this audit | BLOCKED | External mutation intentionally prohibited | Submit only after exact-SHA review and readiness sign-off | Account Holder |

## External verification checklist

### Apple Developer

- [ ] Explicit App ID exists for `com.naoki.wakaremichi`.
- [ ] App ID capability switches match the target (no unintended capabilities).
- [ ] Team `67BCCSD863` owns the App ID and the current account can sign it.
- [ ] A valid Apple Distribution certificate/private key is installed.
- [ ] Automatic signing can create/select a distribution provisioning profile.

### App Store Connect

- [ ] App record exists and uses `com.naoki.wakaremichi`.
- [ ] SKU, primary language, exact app name, category, age rating, copyright, and release method are complete.
- [ ] v1.0 record exists and the uploaded build is selected.
- [ ] Support URL, privacy-policy URL, description, subtitle/omission decision, keywords, and screenshots are complete.
- [ ] App Privacy includes applicable Google Mobile Ads/UMP practices.
- [ ] Territory availability is intentionally selected.

### AdMob

- [ ] App record uses iOS Bundle ID `com.naoki.wakaremichi` and is linked to the production app as appropriate.
- [ ] App ID `ca-app-pub-6219093469517477~7284143930` belongs to that record.
- [ ] Rewarded unit `ca-app-pub-6219093469517477/2031817259` exists under that app.
- [ ] Required Privacy & messaging forms are published for selected territories.
- [ ] Consent/test configuration has been exercised without production ad interaction.

### StoreKit

- [x] Human decision B recorded and implemented: remove-ads purchase UI is hidden for v1.0.
- [x] Collection history is unlimited for all v1.0 users while the purchase feature is disabled.
- [x] Provisional product ID, StoreManager purchase/restore infrastructure, and existing entitlement behavior remain intact.
- [ ] If published in a future version: complete product configuration and expose reviewed purchase and restore entry points together.

## Stop condition

Do not start a signed archive or App Store submission from this snapshot. First complete exact-SHA review of this implementation, then proceed to **External Dashboard Alignment + Signed Archive/Validation**. Apple Developer, App Store Connect, and AdMob remain externally `UNVERIFIED`; no external dashboard was changed by this work unit.
