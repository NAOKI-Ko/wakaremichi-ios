# Result Rewarded Ads + Replay

Status: SPEC READY / IMPLEMENTATION NOT STARTED

This specification defines the next work unit. It does not authorize implementation in the current docs-only work unit.

## Scope and constraints

- Reuse the existing rewarded-ad provider abstraction and Google Mobile Ads SDK integration.
- Reuse the Debug Google official test ad unit ID and the existing Release production rewarded ad unit ID.
- Reuse the existing UMP consent gate.
- Do not change the existing AdMob App ID or rewarded ad unit IDs.
- Do not add interstitial, banner, App Open, or other ad formats.
- Do not add another advertising SDK.
- Preserve gameplay, diagnosis, streak, collection, sharing, StoreKit, and persistence semantics except where this specification explicitly defines the new result and replay gates.

The post-result replay in this specification is distinct from the existing in-session rewarded actions that continue from the current position or restart before an official result is finalized. Implementation must not conflate their state or counters without first confirming the existing runtime design.

## A. Result Gate

After reaching the goal and before displaying the result screen, provide a path through the existing rewarded-ad flow. Present the rewarded ad when the user performs the action to view the result. Display the result after the reward callback succeeds.

Result access must fail open when any of the following occurs:

- The ad is not loaded.
- Ad loading fails.
- Consent state does not permit requesting ads.
- The SDK returns an error.
- The ad cannot be presented.

An advertising failure must never permanently block the result screen or cause the user to lose daily completion or result access. The implementation must define a bounded transition to the result when presentation is unavailable.

If an ad is presented and the user closes it before earning the reward, do not treat that as a successful reward. The implementation must still prioritize preventing a permanent result-access deadlock and provide a safe, explicit way to reach the already-earned result.

## B. Replay Gate

Add an explicit action on the result screen equivalent to:

> 広告を見てもう一度

Start replay only after the rewarded-ad reward callback succeeds. Closing the ad without earning the reward must not start replay.

Replay uses the same date and the same deterministic daily seed as the official run. It starts the same maze from its initial gameplay state; it must not generate a new layout or reroll the day.

## C. Replay semantics

Replay is separate from the official Daily completion. It must not duplicate or overwrite:

- The official `DailyRun` history
- Current streak
- Longest streak
- Total completed days
- Collection or keepsake acquisition
- That day's official completion
- The first official diagnosis result

The first official `DailyRun` must not be deleted, replaced, or overwritten by replay.

Prefer no SwiftData schema change. Represent replay with memory-only state such as an `isReplay` flag or an equivalent transient session state. If implementation investigation proves a schema change unavoidable, stop and request a separate specification decision before changing persistence.

## D. Replay gameplay

During replay, retain normal gameplay behavior:

- Maze exploration
- HP/stamina
- Treasure
- Warp
- Goal arrival
- Result presentation

Reaching the goal during replay may produce a transient result for that replay session, but must not save a new official `DailyRun` or mutate the official completion record.

## E. Ad lifecycle

Reuse the existing:

- Rewarded provider abstraction
- Google Mobile Ads provider
- Debug Google official test rewarded ID: `ca-app-pub-3940256099942544/1712485313`
- Existing Release production rewarded ID
- UMP consent gating and `canRequestAds` behavior

Maintain the existing safe handling for load success/failure, availability, presentation success/failure, reward callbacks, dismissal, and reload. Reward-dependent replay must be granted exactly once and only from the reward callback.

## F. Failure and cancellation

- Rewarded ad closed without reward: do not start replay.
- Rewarded ad unavailable or failed for replay: do not start replay; keep the existing result accessible.
- Result Gate ad unavailable or failed: fail open to the result.
- Consent prevents ad requests: fail open to the result and do not start rewarded replay.
- SDK errors must not crash, corrupt the official run, or strand the UI in a loading state.

## Persistence boundary

No SwiftData schema change is planned. The implementation must preserve the meaning and contents of existing `DailyRun` records and keep replay-only state transient.

## Implementation validation requirements

The implementation work unit must verify at minimum:

- Result access after a successful reward.
- Result fail-open for unloaded, failed, consent-blocked, and presentation-error cases.
- No permanent loading or access block after cancellation or SDK error.
- Replay starts only after reward.
- Replay uses the same daily seed and maze layout.
- Replay resets maze gameplay state.
- Replay does not create, overwrite, or delete the official `DailyRun`.
- Replay does not modify streaks, total completed days, collectibles, official completion, or first diagnosis.
- Replay goal can display a transient result without persistence side effects.
- Debug uses the Google official test rewarded ID.
- Release keeps the existing production rewarded ID.
- Existing tests remain passing, with focused tests added for the result gate, replay gate, failure paths, and persistence boundary.
