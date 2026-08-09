import GoogleMobileAds
import UserMessagingPlatform
import UIKit

/// UMPの同意状態を広告SDKの起動可否へ変換する差し込み口。
/// 実装はGoogle公式フォームを使い、テストはネットワークなしで差し替えられる。
@MainActor
protocol AdConsentProviding {
    func requestConsent(completion: @escaping (Bool) -> Void)
}

/// Google公式UMPフロー。フォームが不要な地域では表示せず即時に完了する。
@MainActor
final class GoogleMobileAdsConsentProvider: AdConsentProviding {
    func requestConsent(completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let parameters = RequestParameters()
            let updateError: Error? = await withCheckedContinuation { continuation in
                ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                    continuation.resume(returning: error)
                }
            }

            if updateError == nil {
                // 同意が必要な地域・状態のときだけ、UMP自身がフォームを表示する。
                try? await ConsentForm.loadAndPresentIfRequired(from: nil)
            }

            // 更新・フォーム表示に失敗しても、前回セッションの有効な同意があれば許可できる。
            completion(ConsentInformation.shared.canRequestAds)
        }
    }
}

/// 同意更新と広告SDK初期化が競合・重複しないための小さな状態機械。
struct AdConsentGate {
    enum State: Equatable {
        case notStarted
        case gathering
        case allowed
        case denied
    }

    private(set) var state: State = .notStarted

    mutating func begin() -> Bool {
        guard state == .notStarted else { return false }
        state = .gathering
        return true
    }

    @discardableResult
    mutating func finish(canRequestAds: Bool) -> Bool? {
        guard state == .gathering else { return nil }
        state = canRequestAds ? .allowed : .denied
        return canRequestAds
    }
}

/// 1回の表示について、rewardと完了をそれぞれ一度だけ受け付ける。
/// SDKコールバックの重複や順序差があっても二重報酬を返さない。
struct RewardedAdSession {
    private(set) var didEarnReward = false
    private(set) var didFinish = false

    @discardableResult
    mutating func recordReward() -> Bool {
        guard !didFinish, !didEarnReward else { return false }
        didEarnReward = true
        return true
    }

    mutating func finish() -> Bool? {
        guard !didFinish else { return nil }
        didFinish = true
        return didEarnReward
    }
}

/// Google Mobile AdsのRewarded専用Provider。
/// Interstitial／Banner／App Openは、このアプリの設計上追加しない。
@MainActor
final class GoogleMobileAdsProvider: NSObject, AdProvider, FullScreenContentDelegate {

    private let rewardedAdUnitID: String
    private let consentProvider: AdConsentProviding
    private var rewardedAd: RewardedAd?
    private var consentGate = AdConsentGate()
    private var hasStartedMobileAds = false
    private var isLoading = false
    private var isPresenting = false
    private var pendingCompletion: ((RewardedAdOutcome) -> Void)?
    private var session = RewardedAdSession()

    convenience init(rewardedAdUnitID: String) {
        self.init(rewardedAdUnitID: rewardedAdUnitID,
                  consentProvider: GoogleMobileAdsConsentProvider())
    }

    init(rewardedAdUnitID: String, consentProvider: AdConsentProviding) {
        self.rewardedAdUnitID = rewardedAdUnitID
        self.consentProvider = consentProvider
    }

    func start() {
        guard consentGate.begin() else { return }
        consentProvider.requestConsent { [weak self] canRequestAds in
            self?.finishConsent(canRequestAds: canRequestAds)
        }
    }

    func showRewardedAdOutcome(completion: @escaping (RewardedAdOutcome) -> Void) {
        guard pendingCompletion == nil, !isPresenting else {
            completion(.unavailable(.busy))
            return
        }

        pendingCompletion = completion
        switch consentGate.state {
        case .notStarted:
            start()
        case .gathering:
            break
        case .allowed:
            presentOrLoad()
        case .denied:
            completePending(.unavailable(.consentBlocked))
        }
    }

    private func finishConsent(canRequestAds: Bool) {
        guard let isAllowed = consentGate.finish(canRequestAds: canRequestAds) else { return }
        guard isAllowed else {
            completePending(.unavailable(.consentBlocked))
            return
        }

        if !hasStartedMobileAds {
            hasStartedMobileAds = true
            MobileAds.shared.start()
        }
        presentOrLoad()
    }

    private func presentOrLoad() {
        if pendingCompletion != nil, let rewardedAd {
            present(rewardedAd)
        } else {
            loadIfNeeded()
        }
    }

    private func loadIfNeeded() {
        guard consentGate.state == .allowed,
              hasStartedMobileAds,
              rewardedAd == nil,
              !isLoading,
              !isPresenting else { return }
        isLoading = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let ad = try await RewardedAd.load(with: rewardedAdUnitID,
                                                   request: Request())
                ad.fullScreenContentDelegate = self
                rewardedAd = ad
                isLoading = false

                if pendingCompletion != nil {
                    present(ad)
                }
            } catch {
                isLoading = false
                completePending(.unavailable(.loadFailed))
            }
        }
    }

    private func present(_ ad: RewardedAd) {
        guard let viewController = Self.topViewController() else {
            rewardedAd = nil
            completePending(.unavailable(.presentationFailed))
            loadIfNeeded()
            return
        }

        session = RewardedAdSession()
        isPresenting = true
        ad.present(from: viewController) { [weak self] in
            self?.session.recordReward()
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        finishPresentation(failure: .presentationFailed)
    }

    private func finishPresentation(failure: RewardedAdFailure? = nil) {
        rewardedAd = nil
        isPresenting = false
        if let didEarnReward = session.finish() {
            if let failure {
                completePending(.unavailable(failure))
            } else {
                completePending(didEarnReward ? .rewarded : .cancelled)
            }
        }
        loadIfNeeded()
    }

    private func completePending(_ outcome: RewardedAdOutcome) {
        guard let completion = pendingCompletion else { return }
        pendingCompletion = nil
        completion(outcome)
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = root as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return root
    }
}
