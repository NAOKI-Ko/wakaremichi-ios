import Foundation

/// SpriteKit側(MazeScene)からSwiftUI側(HUD)へ、探索状況をそのつど渡すための値。
///
/// MazeSceneはSwiftUIから直接observeできないため、移動のたびに
/// `onHUDUpdate` クロージャでこの値を1つ渡す方式にしている。
/// 51x51=2601マス全部ではなく、**霧が晴れた場所(explored)だけ**を渡すので、
/// ミニマップに未探索の迷路が透けて見えてしまう「霧抜け」は起きない。
struct HUDSnapshot {
    var mazeSize: Int
    var player: Coord
    var goal: Coord
    /// 一度でも見えたマス(ミニマップは薄く表示)
    var explored: Set<Coord>
    /// 実際に歩いたマス(ミニマップは濃く表示)
    var walked: Set<Coord>
    var stamina: Int
    var staminaMax: Int
    var traveler: Traveler
}
