import AVFoundation
import SpriteKit

/// BGM・環境音・効果音をまとめて管理する。
///
/// - BGM・環境音: `AVAudioPlayer` でループ再生し、フェードイン/アウトする
/// - 効果音: SpriteKitのシーン内なら `SKAction.playSoundFileNamed`、
///   SwiftUI側(ボタンなど)なら都度 `AVAudioPlayer` を使い捨てで鳴らす。
///   前者は短い音の連打に強く、後者はシーンが無い文脈でも鳴らせる。
final class GameAudio {

    static let shared = GameAudio()
    private init() {}

    enum SFX: String {
        case bump = "sfx_bump"
        case discovery = "sfx_discovery"
        case chest = "sfx_chest"
        case warp = "sfx_warp"
        case goal = "sfx_goal"
        case uiTap = "sfx_ui_tap"
        case cardFlip = "sfx_card_flip"
    }

    // MARK: - BGM / 環境音

    private var bgmPlayer: AVAudioPlayer?
    private var windPlayer: AVAudioPlayer?
    private var fadeTimers: [Timer] = []

    func startBGM() {
        guard Tuning.audioEnabled, bgmPlayer == nil else { return }
        bgmPlayer = Self.makeLoopingPlayer(named: "bgm_musicbox_v4", volume: 0.5)
        bgmPlayer?.play()
    }

    func startAmbientWind() {
        guard Tuning.audioEnabled, windPlayer == nil else { return }
        windPlayer = Self.makeLoopingPlayer(named: "ambient_wind_loop20s", volume: 0.4)
        windPlayer?.play()
    }

    /// 探索を終えて結果画面へ向かうときに呼ぶ。ゆっくり静かになる。
    func stopAmbience(fadeDuration: TimeInterval = 1.2) {
        fade(bgmPlayer, to: 0, duration: fadeDuration) { [weak self] in
            self?.bgmPlayer?.stop(); self?.bgmPlayer = nil
        }
        fade(windPlayer, to: 0, duration: fadeDuration) { [weak self] in
            self?.windPlayer?.stop(); self?.windPlayer = nil
        }
    }

    private func fade(_ player: AVAudioPlayer?,
                      to targetVolume: Float,
                      duration: TimeInterval,
                      completion: @escaping () -> Void) {
        guard let player else { completion(); return }
        let steps = 24
        let stepDuration = duration / Double(steps)
        let startVolume = player.volume
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            i += 1
            let t = Float(i) / Float(steps)
            player.volume = startVolume + (targetVolume - startVolume) * t
            if i >= steps {
                timer.invalidate()
                completion()
            }
        }
        fadeTimers.append(timer)
    }

    private static func makeLoopingPlayer(named name: String, volume: Float) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.numberOfLoops = -1
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    // MARK: - 効果音(SpriteKitシーンから)

    func play(_ sfx: SFX, in scene: SKScene) {
        guard Tuning.audioEnabled else { return }
        scene.run(.playSoundFileNamed(sfx.rawValue + ".wav", waitForCompletion: false))
    }

    /// 足音。3種類をランダムに切り替えて機械的な繰り返し感を消し、
    /// `Tuning.footstepStride` マスに1回だけ鳴らして連打を間引く。
    private let footstepNames = ["sfx_footstep_a", "sfx_footstep_b", "sfx_footstep_c"]
    private var footstepCounter = 0

    func playFootstepIfNeeded(in scene: SKScene) {
        guard Tuning.audioEnabled else { return }
        footstepCounter += 1
        guard footstepCounter % Tuning.footstepStride == 0 else { return }
        let name = footstepNames.randomElement() ?? footstepNames[0]
        scene.run(.playSoundFileNamed(name + ".wav", waitForCompletion: false))
    }

    // MARK: - 効果音(SwiftUI側、シーンが無い文脈)

    private var oneShotPlayers: [AVAudioPlayer] = []

    func play(_ sfx: SFX) {
        guard Tuning.audioEnabled else { return }
        guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav") else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.6
        oneShotPlayers.append(player)
        player.play()
        oneShotPlayers.removeAll { !$0.isPlaying }
    }
}
