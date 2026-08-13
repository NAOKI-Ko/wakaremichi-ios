import StoreKit
import Foundation
import Observation

/// 買い切り(広告削除)を管理する。
///
/// **重要**: `productID` は仮の値。実際に販売するには App Store Connect で
/// Non-Consumable(非消耗型)の製品を作成し、そのIDに置き換える必要がある。
/// ここではStoreKit 2のTransaction検証・購入フロー・復元の「仕組み」だけを
/// 用意しており、実際の製品設定はこちらでは行えない。
@MainActor
@Observable
final class StoreManager {

    static let shared = StoreManager()

    /// App Store Connect で作成する Non-Consumable 製品のID(仮)
    nonisolated static let removeAdsProductID = "com.karemichi.removeads"

    /// v1.0では購入導線を公開しない。将来のrelease用StoreKit基盤と既存entitlementは保持する。
    nonisolated static let isRemoveAdsPurchaseVisibleInV1 = false

    nonisolated static func shouldShowRemoveAdsPurchaseCTA(
        hasLockedRuns: Bool,
        purchaseFeatureEnabled: Bool = isRemoveAdsPurchaseVisibleInV1
    ) -> Bool {
        purchaseFeatureEnabled && hasLockedRuns
    }

    /// 購入状態による分岐をStoreKit Sandboxなしでも検証できる純粋関数。
    nonisolated static func remainingAdActions(isPurchased: Bool,
                                               replayCount: Int,
                                               restartCount: Int) -> Int {
        isPurchased
            ? Int.max
            : max(0, Tuning.maxReplaysPerDay - replayCount - restartCount)
    }

    /// nilは件数制限なしを表す。購入導線を非公開にするreleaseでは、
    /// 非購入者にも解除不能なpaywallを残さず、全履歴を見せる。
    nonisolated static func collectionRunLimit(
        isPurchased: Bool,
        purchaseFeatureEnabled: Bool = isRemoveAdsPurchaseVisibleInV1
    ) -> Int? {
        guard purchaseFeatureEnabled, !isPurchased else { return nil }
        return 7
    }

    /// Collection側がrelease gateを重複実装しないための共通絞り込み。
    nonisolated static func collectionRunsForDisplay<Run>(
        _ runs: [Run],
        isPurchased: Bool,
        purchaseFeatureEnabled: Bool = isRemoveAdsPurchaseVisibleInV1
    ) -> [Run] {
        guard let limit = collectionRunLimit(isPurchased: isPurchased,
                                             purchaseFeatureEnabled: purchaseFeatureEnabled) else {
            return runs
        }
        return Array(runs.prefix(limit))
    }

    private(set) var product: Product?
    private(set) var isPurchased = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactionUpdates()
        Task { await refresh() }
    }

    /// 製品情報の取得と、購入済みかどうかの確認をまとめて行う。
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            product = products.first
        } catch {
            errorMessage = "製品情報の取得に失敗しました"
        }

        await updateEntitlement()
    }

    func purchase() async {
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isPurchased = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入処理に失敗しました"
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await updateEntitlement()
    }

    private func updateEntitlement() async {
        isPurchased = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID {
                isPurchased = true
            }
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                if transaction.productID == Self.removeAdsProductID {
                    await self?.setPurchased(true)
                }
                await transaction.finish()
            }
        }
    }

    private func setPurchased(_ value: Bool) {
        isPurchased = value
    }
}
