import SwiftUI
import SpriteKit
import SwiftData

// MARK: - 進行状態

@Observable
final class RunCoordinator {

    enum Phase {
        case moodInput
        case playing
        case continuePrompt
        case fogFeedback
        case result
    }

    var phase: Phase = .moodInput
    var scene: MazeScene?
    var mood: MoodBefore?
    var feedback: FogFeedback?
    var log: RunLog?
    var axes: PlayStyleAxes = .neutral
    var hud: HUDSnapshot?
    /// ゴール・体力切れ・早抜けで一旦止まった時点の記録。
    var pausedLog: RunLog?
    /// ランダムイベントの選択待ち。表示中は迷路入力を止める。
    var pendingEvent: EventDefinition?
    /// 生成された迷路の自己チェックに失敗したときだけ入る
    var integrityWarning: String?

    let seed: UInt64
    let maze: Maze

    init(date: Date = Date()) {
        let s = DailySeed.seed(for: date)
        seed = s
        maze = Maze.generate(seed: s)

        // 通路が2マス幅になっていないか、ゴールに行けるかを起動時に確認する。
        // 以前の実装で「道が3マス幅に見える」不具合があったため、
        // 同じ壊れ方をしたらすぐ気づけるようにしてある。
        if let wide = maze.firstWideCorridor() {
            integrityWarning = "迷路の生成に異常があります(\(wide.x), \(wide.y) 付近で通路が2マス幅以上)"
        } else if !maze.isGoalReachable() {
            integrityWarning = "迷路の生成に異常があります(ゴールに到達できません)"
        }
    }

    func startPlaying(traveler: Traveler, recentEventThemes: [EventTheme] = []) {
        let game = MazeGame(maze: maze)
        let event = RandomEvents.todaysEvent(dateSeed: seed, recentThemes: recentEventThemes)
        let newScene = MazeScene(game: game, traveler: traveler, event: event)
        newScene.onPausePoint = { [weak self] log in
            guard let self else { return }
            self.pausedLog = log
            self.phase = .continuePrompt
        }
        newScene.onFinish = { [weak self] log in
            guard let self else { return }
            self.log = log
            self.axes = Diagnosis.axes(from: log)
            self.phase = .fogFeedback
        }
        newScene.onHUDUpdate = { [weak self] snapshot in
            self?.hud = snapshot
        }
        newScene.onEventTrigger = { [weak self] event in
            self?.pendingEvent = event
        }
        scene = newScene
        phase = .playing
    }
}

// MARK: - ルート

struct RootView: View {

    @AppStorage("selectedTraveler") private var travelerRaw: String = ""
    @AppStorage("hasSeenPrologue") private var hasSeenPrologue = false
    @Environment(\.modelContext) private var context
    @Query private var allRuns: [DailyRun]

    @State private var coordinator = RunCoordinator()
    @State private var store = StoreManager.shared

    private var traveler: Traveler? {
        travelerRaw.isEmpty ? nil : Traveler(rawValue: travelerRaw)
    }

    private var todaysRun: DailyRun? {
        let today = DailySeed.startOfDay(for: Date())
        return allRuns.first { DailySeed.startOfDay(for: $0.date) == today }
    }

    /// 直近の履歴(古い順、今日ぶんは除く)。
    /// 道しるべのレア判定は「今日が普段とどれだけ違うか」を見るので、
    /// 比較対象に今日を混ぜてしまうと差が薄まる。必ず除外する。
    private var recentAxes: [PlayStyleAxes] {
        let today = DailySeed.startOfDay(for: Date())
        return allRuns
            .filter { DailySeed.startOfDay(for: $0.date) < today }
            .sorted { $0.date < $1.date }
            .map(\.axes)
    }

    /// 今日を除く直近テーマ。過去7日と同じテーマを避けるために使う。
    private var recentEventThemes: [EventTheme] {
        let today = DailySeed.startOfDay(for: Date())
        return allRuns
            .filter { DailySeed.startOfDay(for: $0.date) < today }
            .sorted { $0.date < $1.date }
            .compactMap(\.eventTheme)
    }

    /// 保存直後、@Queryへ今日の記録が届く前でも節目の日数を1日少なく見せない。
    private var totalDayCount: Int {
        guard case .result = coordinator.phase, coordinator.log != nil else {
            return allRuns.count
        }
        return todaysRun == nil ? allRuns.count + 1 : allRuns.count
    }

    /// 既存のクリア済み日だけで算出する。保存直後に `@Query` がまだ更新されて
    /// いない間は、いま完了したクリア日を一時的に加える。
    private var streakSummary: PlayStreakSummary {
        let now = Date()
        let pendingCompletionDate: Date?
        if case .result = coordinator.phase,
           coordinator.log?.reachedGoal == true {
            pendingCompletionDate = now
        } else {
            pendingCompletionDate = nil
        }

        return PlayStreakCalculator.summary(runs: allRuns,
                                            includingCompletionAt: pendingCompletionDate,
                                            asOf: now)
    }

    var body: some View {
        ZStack {
            Palette.backgroundSUI.ignoresSafeArea()

            if let traveler {
                // 保存直後も、いま完了したプレイの結果として見せる。
                // 保存による @Query の更新を先に判定すると、その場でいきなり
                // 「今日は、もう歩きました」に置き換わってしまうため。
                if case .result = coordinator.phase, coordinator.log != nil {
                    playFlow(traveler: traveler)
                } else if let run = todaysRun {
                    // 今日はもう歩き終わっている
                    ResultView(log: run.restoredLog,
                               axes: run.axes,
                               feedback: run.feedback,
                               traveler: run.traveler,
                               seed: UInt64(max(run.seed, 0)),
                               recentAxes: recentAxes,
                               totalDayCount: totalDayCount,
                               currentStreak: streakSummary.currentStreak,
                               resultDate: run.date,
                               alreadyPlayed: true,
                               onClose: nil)
                } else {
                    playFlow(traveler: traveler)
                }
            } else if !hasSeenPrologue {
                PrologueView {
                    hasSeenPrologue = true
                }
            } else {
                TravelerPickerView { picked in
                    travelerRaw = picked.rawValue
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func playFlow(traveler: Traveler) -> some View {
        switch coordinator.phase {

        case .moodInput:
            MoodInputView { picked in
                coordinator.mood = picked
                coordinator.startPlaying(traveler: traveler,
                                         recentEventThemes: recentEventThemes)
            }

        case .playing:
            if let scene = coordinator.scene {
                MazePlayView(scene: scene,
                             warning: coordinator.integrityWarning,
                             hud: coordinator.hud,
                             isInputBlocked: coordinator.pendingEvent != nil)
                    .overlay {
                        if let event = coordinator.pendingEvent {
                            EventChoiceView(event: event) { index in
                                guard scene.resolveEventChoice(index: index) else { return }
                                coordinator.pendingEvent = nil
                            }
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3),
                               value: coordinator.pendingEvent != nil)
            }

        case .continuePrompt:
            if let scene = coordinator.scene, let pausedLog = coordinator.pausedLog {
                ContinuePromptView(
                    log: pausedLog,
                    remainingAdActions: StoreManager.remainingAdActions(
                        isPurchased: store.isPurchased,
                        replayCount: pausedLog.replayCount,
                        restartCount: pausedLog.restartCount
                    ),
                    isPurchased: store.isPurchased,
                    onWatchAdToContinue: {
                        if store.isPurchased {
                            guard scene.resumeAfterAd(ignoringLimit: true) else { return }
                            coordinator.pausedLog = nil
                            coordinator.phase = .playing
                            return
                        }
                        Ads.provider.showRewardedAd { success in
                            // 実広告SDKは任意のキューで完了を返し得るため、
                            // SwiftUIとSpriteKitの状態変更は必ずメインへ戻す。
                            DispatchQueue.main.async {
                                guard success, scene.resumeAfterAd() else { return }
                                coordinator.pausedLog = nil
                                coordinator.phase = .playing
                            }
                        }
                    },
                    onWatchAdToRestart: {
                        if store.isPurchased {
                            guard scene.restartAfterAd(ignoringLimit: true) else { return }
                            coordinator.pausedLog = nil
                            coordinator.phase = .playing
                            return
                        }
                        Ads.provider.showRewardedAd { success in
                            DispatchQueue.main.async {
                                guard success, scene.restartAfterAd() else { return }
                                coordinator.pausedLog = nil
                                coordinator.phase = .playing
                            }
                        }
                    },
                    onFinishHere: {
                        scene.commitFinish()
                    }
                )
            }

        case .fogFeedback:
            FogFeedbackView { picked in
                coordinator.feedback = picked
                save(traveler: traveler)
                coordinator.phase = .result
            }

        case .result:
            if let log = coordinator.log {
                ResultView(log: log,
                           axes: coordinator.axes,
                           feedback: coordinator.feedback,
                           traveler: traveler,
                           seed: coordinator.seed,
                           recentAxes: recentAxes,
                           totalDayCount: totalDayCount,
                           currentStreak: streakSummary.currentStreak,
                           resultDate: Date(),
                           alreadyPlayed: false,
                           onClose: nil)
            }
        }
    }

    private func save(traveler: Traveler) {
        guard let log = coordinator.log else { return }
        let today = DailySeed.startOfDay(for: Date())

        // 同じ日の記録があれば消してから入れ直す(上書き)
        for run in allRuns where DailySeed.startOfDay(for: run.date) == today {
            context.delete(run)
        }

        let run = DailyRun(date: today,
                           seed: Int(coordinator.seed),
                           log: log,
                           axes: coordinator.axes,
                           traveler: traveler,
                           moodBefore: coordinator.mood,
                           fogFeedback: coordinator.feedback)
        context.insert(run)
        try? context.save()
    }
}

// MARK: - プロローグ（初回のみ）

struct PrologueView: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image("PrologueIllustration")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .padding(.horizontal, 40)

            Text("""
            灯りをともす。

            ここは、夢と現実の境目にある、
            小さな洞窟。

            歩くたびに、道は静かに組み替わる。
            あなたの心に合わせて。

            正しい道はありません。
            ただ、今日のあなたが選ぶ道があるだけです。
            """)
            .font(.system(size: 15))
            .lineSpacing(10)
            .foregroundStyle(.white.opacity(0.82))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)

            Spacer()

            Button {
                // UIタップは音だけ。節目のハプティクスとは役割を分ける。
                GameAudio.shared.play(.uiTap)
                onContinue()
            } label: {
                Text("灯りを受け取る")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.backgroundSUI)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.lampSUI, in: Capsule())
            }
            .accessibilityIdentifier("prologueContinueButton")
            .padding(.horizontal, 42)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.backgroundSUI.ignoresSafeArea())
    }
}

// MARK: - ランダムイベント

struct EventChoiceView: View {

    let event: EventDefinition
    let onChoose: (Int) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 24) {
                Text(event.title)
                    .font(.system(size: 16, weight: .medium))
                    .kerning(1.5)
                    .foregroundStyle(Palette.lampSUI.opacity(0.9))

                Image(event.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96)

                Text(event.prompt)
                    .font(.system(size: 14))
                    .lineSpacing(7)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                VStack(spacing: 10) {
                    ForEach(Array(event.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            onChoose(index)
                        } label: {
                            Text(choice.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Palette.surfaceSUI,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("eventChoice_\(index)")
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding(.vertical, 32)
            .background(Palette.backgroundSUI.opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
        }
        .accessibilityIdentifier("eventChoiceOverlay")
    }
}

// MARK: - 一時停止（続きを歩く／今日の結果を見る）

struct ContinuePromptView: View {

    let log: RunLog
    let remainingAdActions: Int
    let isPurchased: Bool
    let onWatchAdToContinue: () -> Void
    let onWatchAdToRestart: () -> Void
    let onFinishHere: () -> Void

    @State private var loadingAction: AdAction?

    private enum AdAction {
        case continueWalk
        case restart
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Text(log.reachedGoal ? "灯りは、ここまで届きました" : "今日は、ここでひと休み")
                .font(.system(size: 19, weight: .medium))
                .kerning(1.5)
                .foregroundStyle(Palette.lampSUI.opacity(0.9))

            Text(log.reachedGoal
                 ? "このまま見るか、まだ見ぬ道を続けて歩くか"
                 : "今日はここまで見るか、もう少し歩いてみるか")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                if remainingAdActions > 0 {
                    adButton(
                        title: isPurchased ? "続きを歩く" : "続きを歩く（広告を見る）",
                        action: .continueWalk,
                        emphasized: true,
                        accessibilityIdentifier: "continueAfterAdButton",
                        onWatch: onWatchAdToContinue
                    )

                    adButton(
                        title: isPurchased ? "はじめからやり直す" : "はじめからやり直す（広告を見る）",
                        action: .restart,
                        emphasized: false,
                        accessibilityIdentifier: "restartAfterAdButton",
                        onWatch: onWatchAdToRestart
                    )

                    if !isPurchased {
                        Text("今日はあと\(remainingAdActions)回まで")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.35))
                            .accessibilityIdentifier("remainingReplaysText")
                    }
                }

                Button {
                    GameAudio.shared.play(.uiTap)
                    onFinishHere()
                } label: {
                    Text("今日はここまで見る")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(loadingAction == nil ? 0.6 : 0.25))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Palette.surfaceSUI, in: Capsule())
                }
                // 広告完了と結果確定が競合しないよう、読込中は片方だけに絞る。
                .disabled(loadingAction != nil)
                .accessibilityIdentifier("finishAtPauseButton")
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.backgroundSUI.ignoresSafeArea())
    }

    @ViewBuilder
    private func adButton(title: String,
                          action: AdAction,
                          emphasized: Bool,
                          accessibilityIdentifier: String,
                          onWatch: @escaping () -> Void) -> some View {
        Button {
            guard loadingAction == nil else { return }
            loadingAction = action
            // UIタップは音だけ。節目のハプティクスとは役割を分ける。
            GameAudio.shared.play(.uiTap)
            onWatch()

            // 広告失敗・途中終了時にも選び直せるようにする。
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                loadingAction = nil
            }
        } label: {
            HStack(spacing: 8) {
                if loadingAction == action {
                    ProgressView().tint(emphasized ? Palette.backgroundSUI : .white)
                }
                Text(loadingAction == action ? "広告を読み込み中..." : title)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(emphasized ? Palette.backgroundSUI : .white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                emphasized ? AnyShapeStyle(Palette.lampSUI) : AnyShapeStyle(Palette.surfaceSUI),
                in: Capsule()
            )
        }
        .disabled(loadingAction != nil)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

// MARK: - 旅人を選ぶ

struct TravelerPickerView: View {

    let onPick: (Traveler) -> Void
    @State private var selection: Traveler?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 10) {
                Text("さいしょの、ひとり")
                    .font(.system(size: 19, weight: .medium))
                    .kerning(2)
                    .foregroundStyle(Palette.lampSUI.opacity(0.9))
                Text("これから一緒に歩く旅人を選んでください")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.top, 40)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(Traveler.allCases) { traveler in
                        Button {
                            GameAudio.shared.play(.uiTap)
                            selection = traveler
                        } label: {
                            VStack(spacing: 10) {
                                Image(traveler.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 96)
                                Text(traveler.displayName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Palette.surfaceSUI.opacity(selection == traveler ? 1 : 0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Palette.lampSUI.opacity(selection == traveler ? 0.8 : 0),
                                            lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("traveler_\(traveler.rawValue)")
                    }
                }
                .padding(.horizontal, 20)
            }

            Button {
                GameAudio.shared.play(.uiTap)
                if let selection { onPick(selection) }
            } label: {
                Text("この旅人と歩く")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.backgroundSUI)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.lampSUI.opacity(selection == nil ? 0.3 : 1), in: Capsule())
            }
            .disabled(selection == nil)
            .accessibilityIdentifier("travelerConfirmButton")
            .padding(.horizontal, 42)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - 探索前の気分

struct MoodInputView: View {

    let onPick: (MoodBefore?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("今日はどんな気分?")
                .font(.system(size: 18, weight: .medium))
                .kerning(1.5)
                .foregroundStyle(Palette.lampSUI.opacity(0.9))

            VStack(spacing: 12) {
                ForEach(MoodBefore.allCases) { mood in
                    Button {
                        GameAudio.shared.play(.uiTap)
                        onPick(mood)
                    } label: {
                        Text(mood.rawValue)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Palette.surfaceSUI, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)

            Spacer()

            Button {
                GameAudio.shared.play(.uiTap)
                onPick(nil)
            } label: {
                Text("こたえずに はじめる")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .accessibilityIdentifier("moodSkipButton")
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 探索後の霧

struct FogFeedbackView: View {

    let onPick: (FogFeedback?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("今日の霧は、どうでしたか?")
                .font(.system(size: 18, weight: .medium))
                .kerning(1.5)
                .foregroundStyle(Palette.lampSUI.opacity(0.9))

            VStack(spacing: 12) {
                ForEach(FogFeedback.allCases) { item in
                    Button {
                        GameAudio.shared.play(.uiTap)
                        onPick(item)
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Palette.surfaceSUI, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)

            Spacer()

            Button {
                GameAudio.shared.play(.uiTap)
                onPick(nil)
            } label: {
                Text("こたえずに すすむ")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .accessibilityIdentifier("fogSkipButton")
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 探索画面

struct MazePlayView: View {

    let scene: MazeScene
    let warning: String?
    let hud: HUDSnapshot?
    /// イベント選択中はSpriteKitのタッチとスワイプ処理を二重に止める。
    var isInputBlocked = false

    var body: some View {
        VStack(spacing: 0) {
            // --- 常設の上部バー ---
            // 早抜けボタンをSpriteViewの外へ出し、迷路の表示領域を覆わない。
            HStack {
                Text("まいにちの分かれ道")
                    .font(.system(size: 15, weight: .medium))
                    .kerning(1.5)
                    .foregroundStyle(Palette.lampSUI.opacity(0.85))

                Spacer()

                Button {
                    GameAudio.shared.play(.uiTap)
                    scene.finishNow()
                } label: {
                    Text("ここまでにする")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Palette.surfaceSUI, in: Capsule())
                }
                .accessibilityIdentifier("finishEarlyButton")
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)

            Image("DividerOrnament")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 10)
                .clipped()
                .padding(.horizontal, 24)
                .opacity(0.8)

            if let warning {
                Text(warning)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(8)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // SKScene自身がscaleMode = .aspectFitを持つため、SwiftUI側では
            // 正方形制約を重ねず、上部バーとHUDの間をそのまま使う。
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .allowsHitTesting(!isInputBlocked)
                .gesture(
                    DragGesture(minimumDistance: Tuning.swipeMinDistance)
                        .onEnded { value in
                            guard !isInputBlocked else { return }
                            let t = value.translation
                            let direction: Direction
                            if abs(t.width) > abs(t.height) {
                                direction = t.width > 0 ? .right : .left
                            } else {
                                direction = t.height > 0 ? .down : .up
                            }
                            scene.receive(direction: direction)
                        }
                )

            // --- 下部HUD: 旅人・体力・ミニマップ ---
            Image("DividerOrnament")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 10)
                .clipped()
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .background(Palette.surfaceSUI)
                .opacity(0.9)

            ExplorationHUD(hud: hud)
                .frame(maxWidth: .infinity)
                .frame(height: 158)
                .background(Palette.surfaceSUI)
                .accessibilityIdentifier("explorationHUD")
        }
    }
}

// MARK: - 下部HUD

struct ExplorationHUD: View {

    let hud: HUDSnapshot?

    var body: some View {
        HStack(spacing: 16) {
            if let hud {
                ZStack {
                    RadialGradient(colors: [Palette.lampSUI.opacity(0.28), .clear],
                                   center: .center, startRadius: 4, endRadius: 60)
                        .frame(width: 108, height: 108)
                    Image(hud.traveler.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(hud.traveler.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .kerning(1)
                        .foregroundStyle(Palette.lampSUI.opacity(0.85))
                    StaminaGauge(remaining: hud.stamina, max: hud.staminaMax)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.vertical, 6)

                MinimapView(hud: hud, size: 128)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(hudTexture)
        .accessibilityElement(children: .contain)
    }

    /// 床の質感を薄く敷いて、単色の背景よりも密度を出す。
    /// 新しい素材は増やさず、既存のMazeFloor画像を再利用している。
    private var hudTexture: some View {
        ZStack {
            Palette.surfaceSUI
            Image("MazeFloor")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.10)
                .clipped()
            Palette.surfaceSUI.opacity(0.55)
        }
    }
}

struct StaminaGauge: View {

    let remaining: Int
    let max: Int

    private var ratio: CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(remaining) / CGFloat(max)
    }

    // 素材(1536x1024)を計測して求めた「窓」の位置(枠画像全体に対する比率)。
    private let windowXInset: CGFloat = 0.140
    private let windowYInset: CGFloat = 0.382
    private let windowHeightRatio: CGFloat = 0.203

    // GeometryReaderへ横幅いっぱいを渡すと、1536:1024の枠が横長に変形して
    // 隣のタイトルやミニマップへ重なる。高さを固定し、素材比率から幅を決める。
    private static let frameHeight: CGFloat = 46
    private static let frameWidth: CGFloat = frameHeight * 1536.0 / 1024.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                Image("StaminaFrame")
                    .resizable()
                    .frame(width: Self.frameWidth, height: Self.frameHeight)

                let windowWidth = Self.frameWidth * (1 - windowXInset * 2)
                let windowHeight = Self.frameHeight * windowHeightRatio * 0.6

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(ratio < 0.2 ? Color.red.opacity(0.75) : Palette.lampSUI.opacity(0.9))
                        .frame(width: windowWidth * Swift.max(0, Swift.min(1, ratio)))
                }
                .frame(width: windowWidth, height: windowHeight)
                .position(x: Self.frameWidth * (windowXInset + (1 - windowXInset * 2) / 2),
                          y: Self.frameHeight * (windowYInset + windowHeightRatio / 2))
            }
            .frame(width: Self.frameWidth, height: Self.frameHeight)

            Text("のこり \(remaining) 歩")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("体力")
        .accessibilityValue("のこり \(remaining) 歩")
        .accessibilityIdentifier("staminaText")
    }
}

// MARK: - ミニマップ

/// 探索済み(explored)のマスだけを描く。未踏の領域は描かないので、
/// ここから迷路全体が透けて見えてしまう「霧抜け」は起きない。
struct MinimapView: View {

    let hud: HUDSnapshot
    var size: CGFloat = 128

    // 素材(1024x1024)の中央窓だけへ、探索済みマスのCanvasを収める。
    private let windowXInset: CGFloat = 242.0 / 1024.0
    private let windowYInset: CGFloat = 264.0 / 1024.0
    private let windowWidthRatio: CGFloat = (778.0 - 242.0) / 1024.0
    private let windowHeightRatio: CGFloat = (754.0 - 264.0) / 1024.0

    var body: some View {
        ZStack {
            minimapCanvas
                .frame(width: size * windowWidthRatio,
                       height: size * windowHeightRatio)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .position(x: size * (windowXInset + windowWidthRatio / 2),
                          y: size * (windowYInset + windowHeightRatio / 2))

            Image("MinimapFrame")
                .resizable()
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ミニマップ")
        .accessibilityIdentifier("minimap")
    }

    private var minimapCanvas: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(hud.mazeSize)

            for coord in hud.explored {
                let isWalked = hud.walked.contains(coord)
                let rect = CGRect(x: CGFloat(coord.x) * cell,
                                  y: CGFloat(coord.y) * cell,
                                  width: max(cell, 1), height: max(cell, 1))
                let color: Color = isWalked
                    ? Palette.lampSUI.opacity(0.9)
                    : Color.white.opacity(0.18)
                context.fill(Path(rect), with: .color(color))
            }

            // ゴール(見えている範囲にあるときだけ)
            if hud.explored.contains(hud.goal) {
                let gx = CGFloat(hud.goal.x) * cell
                let gy = CGFloat(hud.goal.y) * cell
                context.fill(Path(ellipseIn: CGRect(x: gx-1, y: gy-1, width: cell+2, height: cell+2)),
                            with: .color(Palette.goalSUI))
            }

            // 現在地
            let px = CGFloat(hud.player.x) * cell
            let py = CGFloat(hud.player.y) * cell
            context.fill(Path(ellipseIn: CGRect(x: px-1.5, y: py-1.5, width: cell+3, height: cell+3)),
                        with: .color(.white))
        }
        .background(Palette.backgroundSUI.opacity(0.6))
    }
}
