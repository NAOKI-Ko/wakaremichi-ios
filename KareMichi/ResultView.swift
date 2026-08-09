import SwiftUI
import UIKit

// MARK: - 軌跡の線画

struct TrailShape: Shape {

    let points: [Coord]
    let columns: Int
    let rows: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard columns > 0, rows > 0, let first = points.first else { return path }

        let scale = min(rect.width / CGFloat(columns), rect.height / CGFloat(rows))
        let originX = rect.minX + (rect.width - scale * CGFloat(columns)) / 2
        let originY = rect.minY + (rect.height - scale * CGFloat(rows)) / 2

        func position(_ c: Coord) -> CGPoint {
            CGPoint(x: originX + (CGFloat(c.x) + 0.5) * scale,
                    y: originY + (CGFloat(c.y) + 0.5) * scale)
        }

        path.move(to: position(first))
        for coord in points.dropFirst() {
            path.addLine(to: position(coord))
        }
        return path
    }
}

// MARK: - レーダーチャート

struct RadarShape: Shape {

    /// 上から時計回りに4つ。0.0〜1.0
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count == 4 else { return path }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for (i, v) in values.enumerated() {
            let angle = -Double.pi / 2 + Double(i) * (Double.pi / 2)
            let r = radius * max(0.04, CGFloat(v))
            let p = CGPoint(x: center.x + r * CGFloat(cos(angle)),
                            y: center.y + r * CGFloat(sin(angle)))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

struct RadarGridShape: Shape {

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for ring in [0.33, 0.66, 1.0] {
            var ringPath = Path()
            for i in 0..<4 {
                let angle = -Double.pi / 2 + Double(i) * (Double.pi / 2)
                let r = radius * CGFloat(ring)
                let p = CGPoint(x: center.x + r * CGFloat(cos(angle)),
                                y: center.y + r * CGFloat(sin(angle)))
                if i == 0 { ringPath.move(to: p) } else { ringPath.addLine(to: p) }
            }
            ringPath.closeSubpath()
            path.addPath(ringPath)
        }
        for i in 0..<4 {
            let angle = -Double.pi / 2 + Double(i) * (Double.pi / 2)
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                                     y: center.y + radius * CGFloat(sin(angle))))
        }
        return path
    }
}

// MARK: - 結果画面

struct ResultView: View {

    let log: RunLog
    let axes: PlayStyleAxes
    let feedback: FogFeedback?
    let traveler: Traveler
    let seed: UInt64
    let recentAxes: [PlayStyleAxes]
    let totalDayCount: Int
    let currentStreak: Int
    let resultDate: Date
    let alreadyPlayed: Bool
    let onClose: (() -> Void)?

    @State private var trailProgress: CGFloat = 0
    @State private var currentCard = 0
    @State private var showCollection = false
    @State private var shareImage: UIImage?
    @State private var isSharePresented = false

    private var archetype: Archetype { Diagnosis.archetype(for: axes) }

    private var comment: String {
        Diagnosis.comment(feedback: feedback, log: log, axes: axes)
    }

    private var omen: String {
        if let fragment = Diagnosis.storyFragment(totalDayCount: totalDayCount) {
            return fragment
        }
        return Diagnosis.omen(dateSeed: seed,
                              axes: axes,
                              recentAxes: recentAxes,
                              log: log)
    }

    private var reflection: String? {
        Diagnosis.travelerReflection(traveler: traveler, recentAxes: recentAxes)
    }

    /// `recentAxes` は道しるべ用に今日を除外しているため、鏡の通算判定では
    /// 今日の軸を加える。これで通算7日目に、意図どおり6枚目が解放される。
    private var mirror: String? {
        Diagnosis.mirrorReflection(recentAxes: recentAxes + [axes])
    }

    /// 7日目以降は、より長期の比較である鏡カードへ役割を引き継ぐ。
    private var recentTrend: String? {
        guard mirror == nil else { return nil }
        return Diagnosis.recentTrend(axes: axes, recentAxes: recentAxes)
    }

    private var eventReflection: String? {
        Diagnosis.eventReflection(outcome: log.eventOutcome, axes: axes)
    }

    private var keepsake: Keepsake? {
        Keepsake.earned(seed: seed, reachedGoal: log.reachedGoal)
    }

    private var shareContent: ShareCardContent {
        ShareCardContent(log: log,
                         archetype: archetype,
                         traveler: traveler,
                         date: resultDate,
                         currentStreak: currentStreak,
                         keepsake: keepsake)
    }

    var body: some View {
        ZStack {
            Palette.backgroundSUI.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Text(alreadyPlayed ? "今日は、もう歩きました" : (log.reachedGoal ? "今日の探検結果" : "今日はここまで"))
                        .font(.system(size: 16, weight: .medium))
                        .kerning(2)
                        .foregroundStyle(Palette.lampSUI.opacity(0.85))
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    if let onClose {
                        Button {
                            GameAudio.shared.play(.uiTap)
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(8)
                        }
                        .accessibilityIdentifier("resultCloseButton")
                        .padding(.trailing, 12)
                    } else {
                        Button {
                            GameAudio.shared.play(.uiTap)
                            showCollection = true
                        } label: {
                            Image(systemName: "square.grid.3x3")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(8)
                        }
                        .accessibilityIdentifier("openCollectionButton")
                        .padding(.trailing, 12)
                    }
                }
                .padding(.top, 24)

                if log.reachedGoal, currentStreak > 0 {
                    VStack(spacing: 3) {
                        Text("\(currentStreak)日目の旅")
                            .font(.system(size: 13, weight: .medium))
                            .kerning(1.5)
                            .foregroundStyle(Palette.lampSUI.opacity(0.78))

                        Text(currentStreak == 1
                             ? "今日、ひとつ目の灯りがともりました"
                             : "灯りを絶やさず歩いています")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.36))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("currentStreakText")
                }

                TabView(selection: $currentCard) {
                    trailCard.tag(0)
                    tendencyCard.tag(1)
                    commentCard.tag(2)
                    titleCard.tag(3)
                    omenCard.tag(4)
                    if let mirror {
                        mirrorCard(mirror).tag(5)
                    }
                    if let eventReflection {
                        eventCard(eventReflection).tag(6)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Text("横にめくると、続きがあります")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showCollection) {
            CollectionView()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4)) { trailProgress = 1 }
        }
        .onChange(of: currentCard) { _, _ in
            GameAudio.shared.play(.cardFlip)
        }
    }

    // MARK: カード1 探検結果

    private var trailCard: some View {
        card {
            VStack(spacing: 18) {
                Text("今日の探検結果")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.lampSUI.opacity(0.8))

                ZStack {
                    TrailShape(points: log.path,
                               columns: Tuning.mazeSize, rows: Tuning.mazeSize)
                        .trim(from: 0, to: trailProgress)
                        .stroke(Palette.lampSUI.opacity(0.18),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    TrailShape(points: log.path,
                               columns: Tuning.mazeSize, rows: Tuning.mazeSize)
                        .trim(from: 0, to: trailProgress)
                        .stroke(Palette.lampSUI,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .aspectRatio(1, contentMode: .fit)

                HStack(spacing: 22) {
                    stat("歩いたマス数", "\(log.steps)")
                        .accessibilityIdentifier("resultSteps")
                    stat("かかった時間", timeText)
                    stat("見た範囲", "\(percentExplored)%")
                }

                if let keepsake {
                    VStack(spacing: 5) {
                        Text("今日、持ち帰ったもの")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("「\(keepsake.name)」")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.lampSUI.opacity(0.82))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("resultKeepsake")
                }

                let signals = Diagnosis.topSignals(log: log)
                if !signals.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(signals.enumerated()), id: \.offset) { index, signal in
                            HStack(alignment: .top, spacing: 6) {
                                Text("・")
                                Text(signal.phrase)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("behaviorSignal\(index)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
                    .accessibilityIdentifier("behaviorSignals")
                }

                shareButton
            }
        }
        .accessibilityIdentifier("resultCardTrail")
    }

    private var shareButton: some View {
        Button {
            GameAudio.shared.play(.uiTap)
            shareImage = ShareImageRenderer.render(content: shareContent)
            isSharePresented = shareImage != nil
        } label: {
            Label("共有", systemImage: "square.and.arrow.up")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
        }
        .accessibilityIdentifier("shareResultButton")
        .padding(.top, 2)
        .sheet(isPresented: $isSharePresented) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
    }

    // MARK: カード2 傾向

    private var tendencyCard: some View {
        card {
            VStack(spacing: 16) {
                Text("今日のあなたの傾向")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.lampSUI.opacity(0.8))

                ZStack {
                    RadarGridShape()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                    RadarShape(values: [axes.intuition, axes.exploration,
                                        axes.caution, axes.flexibility])
                        .fill(Palette.lampSUI.opacity(0.28))
                    RadarShape(values: [axes.intuition, axes.exploration,
                                        axes.caution, axes.flexibility])
                        .stroke(Palette.lampSUI, lineWidth: 1.5)
                }
                .frame(width: 170, height: 170)
                .overlay(alignment: .top) {
                    Text("直感性").font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5)).offset(y: -16)
                }
                .overlay(alignment: .trailing) {
                    Text("探索性").font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5)).offset(x: 30)
                }
                .overlay(alignment: .bottom) {
                    Text("慎重性").font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5)).offset(y: 16)
                }
                .overlay(alignment: .leading) {
                    Text("柔軟性").font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5)).offset(x: -30)
                }

                VStack(spacing: 6) {
                    Text(axes.personalityCode)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .kerning(3)
                        .foregroundStyle(Palette.lampSUI.opacity(0.75))
                        .accessibilityIdentifier("personalityCode")
                    Text(archetype.fullName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(archetype.flavor)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)

                if let recentTrend {
                    Text(recentTrend)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .accessibilityIdentifier("recentTrend")
                }
            }
        }
        .accessibilityIdentifier("resultCardTendency")
    }

    // MARK: カード3 ひとこと

    private var commentCard: some View {
        card {
            VStack(spacing: 18) {
                Text("今日のひとこと")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.lampSUI.opacity(0.8))

                Text(comment)
                    .font(.system(size: 15))
                    .lineSpacing(7)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                if let reflection {
                    Divider().background(.white.opacity(0.12)).padding(.horizontal, 20)
                    Text(reflection)
                        .font(.system(size: 12))
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
        }
        .accessibilityIdentifier("resultCardComment")
    }

    // MARK: カード4 称号

    private var recurringArchetype: Archetype? {
        Diagnosis.recurringArchetype(recentAxes: recentAxes + [axes])
    }

    private var titleCard: some View {
        card {
            VStack(spacing: 20) {
                Text("今日の称号")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.lampSUI.opacity(0.8))

                Image("TitleSeal")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)

                Text(archetype.base)
                    .font(.system(size: 20, weight: .medium))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.92))

                if let recurringArchetype {
                    Text("最近14日でよく現れる旅の姿:「\(recurringArchetype.fullName)」")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
            }
        }
        .accessibilityIdentifier("resultCardTitle")
    }

    // MARK: カード5 道しるべ

    private var omenCard: some View {
        card {
            VStack(spacing: 18) {
                Text("今日の道しるべ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.lampSUI.opacity(0.8))

                Image(traveler.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 84)
                    .opacity(0.9)

                Text(omen)
                    .font(.system(size: 14))
                    .lineSpacing(7)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .accessibilityIdentifier("resultCardOmen")
    }

    // MARK: カード6 鏡（通算7日目から）

    private func mirrorCard(_ text: String) -> some View {
        card {
            VStack(spacing: 18) {
                Text("鏡")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.lampSUI.opacity(0.8))

                Image("MirrorOrnament")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                Text(text)
                    .font(.system(size: 14))
                    .lineSpacing(9)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .accessibilityIdentifier("resultCardMirror")
    }

    // MARK: カード7 心の分かれ道

    private func eventCard(_ text: String) -> some View {
        card {
            VStack(spacing: 18) {
                Text("心の分かれ道")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.lampSUI.opacity(0.8))

                Image("EventCardOrnament")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 88)

                Text(text)
                    .font(.system(size: 14))
                    .lineSpacing(9)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .accessibilityIdentifier("resultCardEvent")
    }

    // MARK: 共通

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Palette.surfaceSUI.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 22)
        .padding(.bottom, 34)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .accessibilityElement(children: .combine)
    }

    private var timeText: String {
        let total = Int(log.elapsed.rounded())
        return String(format: "%d分%02d秒", total / 60, total % 60)
    }

    private var percentExplored: Int {
        guard log.openCellCount > 0 else { return 0 }
        return Int((Double(log.exploredCellCount) / Double(log.openCellCount) * 100).rounded())
    }
}

/// 標準共有シートをSwiftUIから表示する薄いラッパー。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: Context) {}
}
