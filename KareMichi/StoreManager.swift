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

    /// 購入状態による分岐をStoreKit Sandboxなしでも検証できる純粋関数。
    nonisolated static func remainingAdActions(isPurchased: Bool,
                                               replayCount: Int,
                                               restartCount: Int) -> Int {
        isPurchased
            ? Int.max
            : max(0, Tuning.maxReplaysPerDay - replayCount - restartCount)
    }

    /// nilは件数制限なしを表す。
    nonisolated static func collectionRunLimit(isPurchased: Bool) -> Int? {
        isPurchased ? nil : 7
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
