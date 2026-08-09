import Foundation

/// 「もう一度探索する」で見せるリワード広告の差し込み口。
/// ゲーム側はSDKの型を知らず、reward成立時のBoolだけを受け取る。
@MainActor
protocol AdProvider {
    func start()
    func showRewardedAd(completion: @escaping (Bool) -> Void)
}

extension AdProvider {
    func start() {}
}

/// Unit Test専用。ネットワークや本番広告へ接続しない。
struct MockAdProvider: AdProvider {
    let result: Bool
    let delay: TimeInterval

    init(result: Bool = true, delay: TimeInterval = 1.0) {
        self.result = result
        self.delay = delay
    }

    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion(result)
        }
    }
}

/// 設定不足時にゲームを止めず、広告失敗として元の選択画面へ戻す。
struct UnavailableAdProvider: AdProvider {
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        completion(false)
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
