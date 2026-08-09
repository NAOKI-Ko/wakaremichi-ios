import Foundation

/// 「もう一度探索する」で見せるリワード広告の差し込み口。
///
/// 現時点では広告SDKへ接続せず、`MockAdProvider`が1秒待って成功を返す。
/// 実SDK導入時はこのprotocolへ準拠する型を作り、`Ads.provider`を差し替える。
protocol AdProvider {
    /// 視聴完了ならtrue、途中終了または失敗ならfalseを返す。
    func showRewardedAd(completion: @escaping (Bool) -> Void)
}

struct MockAdProvider: AdProvider {
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
}

enum Ads {
    /// 実際の広告SDKが決まったら、この実装だけを差し替える。
    static var provider: AdProvider = MockAdProvider()
}
