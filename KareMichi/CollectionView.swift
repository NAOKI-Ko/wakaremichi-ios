import SwiftUI
import SwiftData

/// 日付ごとに歩いた軌跡を並べる画面。「積み重なっていく実感」を作る、
/// 唯一の未実装ピースだったもの。
struct CollectionView: View {

    @Query(sort: \DailyRun.date, order: .reverse) private var allRuns: [DailyRun]
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared

    @State private var selected: DailyRun?

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let keepsakeColumns = [GridItem(.flexible()), GridItem(.flexible())]

    private var acquiredKeepsakes: Set<Keepsake> {
        Keepsake.acquired(from: allRuns)
    }

    /// 買い切り前は直近7件だけ見せる。「全部の旅の記録」を買い切りで解除する。
    private var visibleRuns: [DailyRun] {
        if let limit = StoreManager.collectionRunLimit(isPurchased: store.isPurchased) {
            return Array(allRuns.prefix(limit))
        }
        return allRuns
    }

    private var hasLockedRuns: Bool {
        !store.isPurchased && allRuns.count > 7
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
                        if hasLockedRuns {
                            unlockBanner
                        }
                    }
                }
            }
        }
        .sheet(item: $selected) { run in
            CollectionDetailView(run: run) { selected = nil }
        }
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
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isAcquired
                                  ? Palette.lampSUI.opacity(0.7)
                                  : Color.white.opacity(0.08))
                            .frame(width: 7, height: 7)

                        Text(isAcquired ? keepsake.name : "まだ見つけていないもの")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(isAcquired ? 0.68 : 0.24))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Palette.surfaceSUI.opacity(isAcquired ? 0.55 : 0.28),
                                in: RoundedRectangle(cornerRadius: 9))
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
    let onClose: () -> Void

    var body: some View {
        ResultView(log: run.restoredLog,
                  axes: run.axes,
                  feedback: run.feedback,
                  traveler: run.traveler,
                  seed: UInt64(max(run.seed, 0)),
                  recentAxes: [],
                  totalDayCount: 0,
                  currentStreak: 0,
                  resultDate: run.date,
                  alreadyPlayed: true,
                  onClose: onClose)
    }
}
