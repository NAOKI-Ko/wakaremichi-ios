import Foundation

enum RewardedAdFailure: Equatable {
    case notLoaded
    case loadFailed
    case consentBlocked
    case presentationFailed
    case sdkError
    case busy
}

enum RewardedAdOutcome: Equatable {
    case rewarded
    case cancelled
    case unavailable(RewardedAdFailure)

    var didEarnReward: Bool { self == .rewarded }
}

/// 「もう一度探索する」で見せるリワード広告の差し込み口。
/// ゲーム側はSDKの型を知らず、reward／cancel／提示不能だけを受け取る。
@MainActor
protocol AdProvider {
    func start()
    func showRewardedAdOutcome(completion: @escaping (RewardedAdOutcome) -> Void)
}

extension AdProvider {
    func start() {}

    /// 既存の「続きから／はじめから」は成功可否だけを必要とするため、
    /// 従来のBool APIを残して呼び出し側の意味を変えない。
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        showRewardedAdOutcome { outcome in
            completion(outcome.didEarnReward)
        }
    }
}

/// Unit Test専用。ネットワークや本番広告へ接続しない。
struct MockAdProvider: AdProvider {
    let outcome: RewardedAdOutcome
    let delay: TimeInterval

    init(result: Bool = true, delay: TimeInterval = 1.0) {
        self.outcome = result ? .rewarded : .cancelled
        self.delay = delay
    }

    init(outcome: RewardedAdOutcome, delay: TimeInterval = 0) {
        self.outcome = outcome
        self.delay = delay
    }

    func showRewardedAdOutcome(completion: @escaping (RewardedAdOutcome) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion(outcome)
        }
    }
}

/// 設定不足時にゲームを止めず、広告失敗として元の選択画面へ戻す。
struct UnavailableAdProvider: AdProvider {
    func showRewardedAdOutcome(completion: @escaping (RewardedAdOutcome) -> Void) {
        completion(.unavailable(.notLoaded))
    }
}

enum RewardedGateKind: Equatable {
    case result
    case replay
}

enum RewardedGateAction: Equatable {
    case none
    case stay
    case showResult
    case startReplay
}

/// Result GateとReplay Gateで共有する、UI非依存のexactly-once状態機械。
/// Resultだけは広告提示不能時にfail-openし、Replayはreward時だけ許可する。
struct RewardedGateState {
    let kind: RewardedGateKind
    private(set) var isRequestInFlight = false
    private(set) var didTransition = false
    private(set) var allowsResultFallback = false

    mutating func beginRequest() -> Bool {
        guard !isRequestInFlight, !didTransition else { return false }
        isRequestInFlight = true
        return true
    }

    mutating func resolve(_ outcome: RewardedAdOutcome) -> RewardedGateAction {
        guard isRequestInFlight, !didTransition else { return .none }
        isRequestInFlight = false

        switch (kind, outcome) {
        case (.result, .rewarded):
            didTransition = true
            return .showResult
        case (.result, .unavailable):
            // 正式結果はすでに確定済み。広告障害で閲覧を失わせない。
            didTransition = true
            return .showResult
        case (.result, .cancelled):
            allowsResultFallback = true
            return .stay
        case (.replay, .rewarded):
            didTransition = true
            return .startReplay
        case (.replay, .cancelled), (.replay, .unavailable):
            return .stay
        }
    }

    mutating func useResultFallback() -> RewardedGateAction {
        guard kind == .result,
              allowsResultFallback,
              !isRequestInFlight,
              !didTransition else { return .none }
        didTransition = true
        return .showResult
    }
}

enum AdConfiguration {
    static let rewardedAdUnitIDKey = "KareMichiRewardedAdUnitID"

    static func rewardedAdUnitID(bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: rewardedAdUnitIDKey) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
enum Ads {
    /// 通常実行はGoogle Mobile Adsへ接続し、XCTest実行中だけMockへ差し替える。
    /// Debug／Releaseの広告ID切替はXcodeのBuild Settingsで行う。
    static var provider: AdProvider = makeDefaultProvider()

    static func start() {
        provider.start()
    }

    static func makeDefaultProvider(
        isRunningUnitTests: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    ) -> AdProvider {
        if isRunningUnitTests {
            return MockAdProvider()
        }

        guard let adUnitID = AdConfiguration.rewardedAdUnitID() else {
            return UnavailableAdProvider()
        }
        return GoogleMobileAdsProvider(rewardedAdUnitID: adUnitID)
    }
}
