import SwiftUI
import SwiftData

/// 日付ごとに歩いた軌跡を並べる画面。「積み重なっていく実感」を作る、
/// 唯一の未実装ピースだったもの。
struct CollectionView: View {

    @Query(sort: \DailyRun.date, order: .reverse) private var allRuns: [DailyRun]
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared
    @State private var privacyOptions = PrivacyOptionsManager.shared

    @State private var selected: DailyRun?

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let keepsakeColumns = [GridItem(.flexible()), GridItem(.flexible())]

    private var acquiredKeepsakes: Set<Keepsake> {
        Keepsake.acquired(from: allRuns)
    }

    /// v1は購入機能を非公開にしているため全件表示する。
    /// 将来再公開するときはStoreManager側の同じrelease gateで7件制限を戻せる。
    private var visibleRuns: [DailyRun] {
        StoreManager.collectionRunsForDisplay(allRuns,
                                              isPurchased: store.isPurchased)
    }

    private var hasLockedRuns: Bool {
        visibleRuns.count < allRuns.count
    }

    var body: some View {
        ZStack {
            Palette.backgroundSUI.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if allRuns.isEmpty {
                    ScrollView {
                        keepsakeShelf
                        emptyState
                            .frame(minHeight: 240)
                    }
                } else {
                    ScrollView {
                        keepsakeShelf
                        summaryRow
                        grid
                        if StoreManager.shouldShowRemoveAdsPurchaseCTA(hasLockedRuns: hasLockedRuns) {
                            unlockBanner
                        }
                    }
                }

                CollectionPrivacyOptionsControl(manager: privacyOptions)
            }
        }
        .sheet(item: $selected) { run in
            CollectionDetailView(run: run,
                                 currentStreak: streak(on: run)) {
                selected = nil
            }
        }
        .onAppear {
            privacyOptions.refreshRequirement()
        }
    }

    /// 過去の結果から共有するときも、Cycle 1と同じ算出器で当時の連続日数を復元する。
    private func streak(on run: DailyRun) -> Int {
        let runDay = DailySeed.startOfDay(for: run.date)
        let historyThroughRun = allRuns.filter {
            DailySeed.startOfDay(for: $0.date) <= runDay
        }
        return PlayStreakCalculator.summary(runs: historyThroughRun,
                                            asOf: run.date).currentStreak
    }

    private var header: some View {
        HStack {
            Text("旅の記録")
                .font(.system(size: 17, weight: .medium))
                .kerning(2)
                .foregroundStyle(Palette.lampSUI.opacity(0.85))
            Spacer()
            Button {
                GameAudio.shared.play(.uiTap)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(10)
                    .background(Palette.surfaceSUI, in: Circle())
            }
            .accessibilityIdentifier("collectionCloseButton")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("EmptyLantern")
                .resizable()
                .scaledToFit()
                .frame(height: 96)
                .opacity(0.85)
            Text("まだ、記録がありません")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
            Text("今日の一歩から、少しずつ増えていきます")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryRow: some View {
        HStack(spacing: 24) {
            summaryStat("通算日数", "\(allRuns.count)")
            summaryStat("ゴール到達", "\(allRuns.filter(\.reachedGoal).count)")
            summaryStat("出会った日", "\(allRuns.filter { $0.eventTheme != nil }.count)")
        }
        .padding(.vertical, 16)
    }

    private var keepsakeShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("持ち帰ったもの")
                    .font(.system(size: 13, weight: .medium))
                    .kerning(1)
                    .foregroundStyle(Palette.lampSUI.opacity(0.75))
                Spacer()
                Text("\(acquiredKeepsakes.count) / \(Keepsake.v1Catalog.count)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }

            LazyVGrid(columns: keepsakeColumns, spacing: 8) {
                ForEach(Keepsake.v1Catalog) { keepsake in
                    let isAcquired = acquiredKeepsakes.contains(keepsake)
                    HStack(spacing: 10) {
                        Image(keepsake.assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .saturation(isAcquired ? 1 : 0)
                            .brightness(isAcquired ? 0 : -0.28)
                            .opacity(isAcquired ? 0.95 : 0.22)
                            .frame(width: 52, height: 52)
                            .shadow(color: isAcquired
                                    ? Palette.lampSUI.opacity(0.16)
                                    : .clear,
                                    radius: 7)

                        Text(isAcquired ? keepsake.name : "まだ見つけていないもの")
                            .font(.system(size: 11, weight: isAcquired ? .medium : .regular))
                            .foregroundStyle(.white.opacity(isAcquired ? 0.74 : 0.3))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Palette.surfaceSUI.opacity(isAcquired ? 0.58 : 0.3))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Palette.lampSUI.opacity(isAcquired ? 0.09 : 0.03),
                                            lineWidth: 0.7)
                            }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isAcquired
                                        ? "入手済み、\(keepsake.name)"
                                        : "未入手")
                    .accessibilityIdentifier("keepsake_\(keepsake.id)")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .accessibilityIdentifier("keepsakeCollection")
    }

    private func summaryStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(visibleRuns, id: \.persistentModelID) { run in
                Button {
                    GameAudio.shared.play(.uiTap)
                    selected = run
                } label: {
                    CollectionThumbnail(run: run)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("collectionRun_\(Int(run.date.timeIntervalSince1970))")
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, hasLockedRuns ? 6 : 30)
    }

    private var unlockBanner: some View {
        VStack(spacing: 10) {
            Text("これより前の記録は、買い切りで解除できます")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))

            Button {
                GameAudio.shared.play(.uiTap)
                Task { await store.purchase() }
            } label: {
                Text(store.product.map { "旅の記録をすべて見る(\($0.displayPrice))" } ?? "旅の記録をすべて見る")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.backgroundSUI)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.lampSUI, in: Capsule())
            }
            .disabled(store.product == nil || store.isLoading)
            .accessibilityIdentifier("collectionPurchaseButton")
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 30)
    }
}

// MARK: - Privacy options

struct CollectionPrivacyOptionsControl: View {

    @Bindable var manager: PrivacyOptionsManager

    var body: some View {
        if manager.isVisible {
            VStack(spacing: 5) {
                Button {
                    GameAudio.shared.play(.uiTap)
                    Task { await manager.presentPrivacyOptions() }
                } label: {
                    HStack(spacing: 6) {
                        if manager.isPresenting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.55))
                        }
                        Image(systemName: "hand.raised")
                        Text("プライバシー設定")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.surfaceSUI.opacity(0.42), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(manager.isPresenting)
                .accessibilityIdentifier("privacyOptionsButton")

                if let errorMessage = manager.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                        .accessibilityIdentifier("privacyOptionsError")
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
            .accessibilityIdentifier("privacyOptionsControl")
        }
    }
}

// MARK: - サムネイル

struct CollectionThumbnail: View {

    let run: DailyRun

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: run.date)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Palette.surfaceSUI)

                TrailShape(points: run.path, columns: Tuning.mazeSize, rows: Tuning.mazeSize)
                    .stroke(Palette.lampSUI.opacity(run.reachedGoal ? 0.9 : 0.5),
                           style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .padding(10)

                if run.reachedGoal {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.goalSUI)
                        .padding(5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(4)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Text(dateText)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - 詳細(過去の1日を見返す)

struct CollectionDetailView: View {

    let run: DailyRun
    let currentStreak: Int
    let onClose: () -> Void

    var body: some View {
        ResultView(log: run.restoredLog,
                  axes: run.axes,
                  feedback: run.feedback,
                  traveler: run.traveler,
                  seed: UInt64(max(run.seed, 0)),
                  recentAxes: [],
                  totalDayCount: 0,
                  currentStreak: currentStreak,
                  resultDate: run.date,
                  alreadyPlayed: true,
                  isReplay: false,
                  isPurchased: false,
                  adProvider: nil,
                  onReplay: nil,
                  onClose: onClose)
    }
}
