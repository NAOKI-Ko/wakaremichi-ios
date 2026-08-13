import SpriteKit
import UIKit

struct MazeCameraBounds: Equatable {
    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat

    func contains(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX
            && point.y >= minY && point.y <= maxY
    }
}

enum MazeCameraGeometry {
    static func bounds(worldSize: CGSize,
                       viewportSize: CGSize,
                       edgeContextMargin: CGFloat) -> MazeCameraBounds {
        let x = axisBounds(world: worldSize.width,
                           viewport: viewportSize.width,
                           edgeContextMargin: edgeContextMargin)
        let y = axisBounds(world: worldSize.height,
                           viewport: viewportSize.height,
                           edgeContextMargin: edgeContextMargin)
        return MazeCameraBounds(minX: x.lowerBound,
                                maxX: x.upperBound,
                                minY: y.lowerBound,
                                maxY: y.upperBound)
    }

    static func clampedPosition(_ desired: CGPoint,
                                worldSize: CGSize,
                                viewportSize: CGSize,
                                edgeContextMargin: CGFloat) -> CGPoint {
        let validBounds = bounds(worldSize: worldSize,
                                 viewportSize: viewportSize,
                                 edgeContextMargin: edgeContextMargin)
        let fallback = CGPoint(x: (validBounds.minX + validBounds.maxX) / 2,
                               y: (validBounds.minY + validBounds.maxY) / 2)
        let desiredX = desired.x.isFinite ? desired.x : fallback.x
        let desiredY = desired.y.isFinite ? desired.y : fallback.y
        return CGPoint(x: min(max(desiredX, validBounds.minX), validBounds.maxX),
                       y: min(max(desiredY, validBounds.minY), validBounds.maxY))
    }

    private static func axisBounds(world: CGFloat,
                                   viewport: CGFloat,
                                   edgeContextMargin: CGFloat) -> ClosedRange<CGFloat> {
        let world = sanitizedDimension(world)
        let viewport = sanitizedDimension(viewport)
        let requestedMargin = edgeContextMargin.isFinite ? max(edgeContextMargin, 0) : 0
        let halfViewport = viewport / 2
        // Overscanは最大でもviewportの半分。通常はMazeScene側から1タイルだけ渡す。
        let overscan = min(requestedMargin, halfViewport)
        let lower = halfViewport - overscan
        let upper = world - halfViewport + overscan

        guard lower <= upper else {
            let center = world / 2
            return center...center
        }
        return lower...upper
    }

    private static func sanitizedDimension(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(value, 0) : 0
    }
}

struct MazeGameplaySafeInsets: Equatable {
    let left: CGFloat
    let right: CGFloat
    let top: CGFloat
    let bottom: CGFloat
}

/// world由来のcamera範囲だけでなく、最終的に表示されるvisual frameを
/// SpriteView内部の安全領域へ収めるためのcamera solver。
enum MazeCameraSafetyGeometry {
    static func gameplaySafeRect(viewportSize: CGSize,
                                 insets: MazeGameplaySafeInsets) -> CGRect {
        gameplaySafeRect(viewportBounds: CGRect(origin: .zero, size: viewportSize),
                         insets: insets)
    }

    static func gameplaySafeRect(viewportBounds: CGRect,
                                 insets: MazeGameplaySafeInsets) -> CGRect {
        let width = sanitizedDimension(viewportBounds.width)
        let height = sanitizedDimension(viewportBounds.height)
        let left = sanitizedInset(insets.left, limit: width / 2)
        let right = sanitizedInset(insets.right, limit: width / 2)
        let top = sanitizedInset(insets.top, limit: height / 2)
        let bottom = sanitizedInset(insets.bottom, limit: height / 2)
        return CGRect(x: viewportBounds.minX + left,
                      y: viewportBounds.minY + top,
                      width: max(width - left - right, 0),
                      height: max(height - top - bottom, 0))
    }

    static func resolvedPosition(_ desired: CGPoint,
                                 worldSize: CGSize,
                                 viewportSize: CGSize,
                                 visibleViewportRect: CGRect? = nil,
                                 safeInsets: MazeGameplaySafeInsets,
                                 maximumOutsideWorldReveal: CGFloat,
                                 requiredFrames: [CGRect],
                                 optionalFrames: [CGRect] = []) -> CGPoint {
        let worldBounds = MazeCameraGeometry.bounds(
            worldSize: worldSize,
            viewportSize: viewportSize,
            edgeContextMargin: maximumOutsideWorldReveal
        )
        let fallback = CGPoint(x: (worldBounds.minX + worldBounds.maxX) / 2,
                               y: (worldBounds.minY + worldBounds.maxY) / 2)
        let desired = CGPoint(x: desired.x.isFinite ? desired.x : fallback.x,
                              y: desired.y.isFinite ? desired.y : fallback.y)

        guard let requiredBounds = constrainedBounds(
            base: worldBounds,
            viewportSize: viewportSize,
            visibleViewportRect: visibleViewportRect,
            safeInsets: safeInsets,
            protectedFrames: requiredFrames
        ) else {
            return clamped(desired, to: worldBounds)
        }

        let selectedBounds: MazeCameraBounds
        if !optionalFrames.isEmpty,
           let combined = constrainedBounds(
               base: requiredBounds,
               viewportSize: viewportSize,
               visibleViewportRect: visibleViewportRect,
               safeInsets: safeInsets,
               protectedFrames: optionalFrames
           ) {
            selectedBounds = combined
        } else {
            selectedBounds = requiredBounds
        }
        return clamped(desired, to: selectedBounds)
    }

    private static func constrainedBounds(base: MazeCameraBounds,
                                          viewportSize: CGSize,
                                          visibleViewportRect: CGRect?,
                                          safeInsets: MazeGameplaySafeInsets,
                                          protectedFrames: [CGRect]) -> MazeCameraBounds? {
        let width = sanitizedDimension(viewportSize.width)
        let height = sanitizedDimension(viewportSize.height)
        let viewportBounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        let visibleRect = (visibleViewportRect ?? viewportBounds).intersection(viewportBounds)
        let safeRect = gameplaySafeRect(viewportBounds: visibleRect, insets: safeInsets)
        guard safeRect.width > 0, safeRect.height > 0 else { return nil }

        let halfWidth = width / 2
        let halfHeight = height / 2
        var minX = base.minX
        var maxX = base.maxX
        var minY = base.minY
        var maxY = base.maxY

        for frame in protectedFrames where !frame.isNull && !frame.isInfinite {
            // SpriteKit scene座標は下原点。safeRectはviewの上原点なので、
            // top/bottomのinsetを対応させてcameraの許容範囲へ変換する。
            minX = max(minX, frame.maxX + halfWidth - safeRect.maxX)
            maxX = min(maxX, frame.minX + halfWidth - safeRect.minX)
            minY = max(minY, frame.maxY - halfHeight + safeRect.minY)
            maxY = min(maxY, frame.minY - halfHeight + safeRect.maxY)
        }

        guard minX <= maxX, minY <= maxY else { return nil }
        return MazeCameraBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    private static func clamped(_ point: CGPoint, to bounds: MazeCameraBounds) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    private static func sanitizedDimension(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(value, 0) : 0
    }

    private static func sanitizedInset(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        value.isFinite ? min(max(value, 0), max(limit, 0)) : 0
    }
}

enum MazeTileKind {
    case floor
    case wall
}

enum MazeTileSource {
    static let floorTextureName = "MazeFloor"
    static let wallTextureName = "MazeWall"

    static func textureName(for kind: MazeTileKind) -> String {
        switch kind {
        case .floor: return floorTextureName
        case .wall: return wallTextureName
        }
    }
}

final class MazeScene: SKScene {

    let game: MazeGame
    let traveler: Traveler
    var onFinish: ((RunLog) -> Void)?
    /// ゴール・体力切れ・手動終了で一時停止したときに呼ぶ。
    /// 結果は`commitFinish()`が呼ばれるまで確定しない。
    var onPausePoint: ((RunLog) -> Void)?
    /// 移動のたびに呼ばれる。ミニマップ・体力ゲージなど、SwiftUI側のHUD更新に使う。
    var onHUDUpdate: ((HUDSnapshot) -> Void)?
    /// イベント地点へ着いたら呼ぶ。選択中の入力制御とUIはSwiftUI側で行う。
    var onEventTrigger: ((EventDefinition) -> Void)?
    let todaysEvent: EventDefinition?
    private var pendingEventShown = false

    private static let tile: CGFloat = 40
    /// SpriteView内部でplayerと進路文脈を端へ密着させないための余白。
    /// HUDはSpriteView外なので、112ptをここで再控除しない。
    static let gameplaySafeInsets = MazeGameplaySafeInsets(
        left: tile,
        right: tile,
        top: tile,
        bottom: tile
    )
    /// 1タイルのsafe inset + 約1タイルのnavigation contextから導出した上限。
    static let maximumOutsideWorldReveal = tile * 2
    private static let playerContextPadding = tile
    private static let nearbyGoalDistance = tile * 3
    private static let goalPulseMaximumScale: CGFloat = 1.10

    /// 一度でも見えたマスだけノードを作る。51x51=2601マスぶんを最初に全部
    /// 生成すると重いので、霧が晴れた場所から遅延生成する。
    private var tileNodes: [Coord: SKNode] = [:]
    private var floorTints: [Coord: SKSpriteNode] = [:]
    private var chestNodes: [Coord: SKSpriteNode] = [:]
    private var warpNodes: [Coord: SKSpriteNode] = [:]
    private var goalNode: SKSpriteNode?
    private var playerNode: SKSpriteNode!
    private var glowNode: SKSpriteNode!
    private var cameraNode: SKCameraNode!
    private var vignetteNode: SKSpriteNode?

    private var isWalking = false
    private var finished = false

    // v1.0は床／壁の即時判別を優先し、source textureを各1種類に固定する。
    private static let floorTexture = SKTexture(imageNamed: MazeTileSource.textureName(for: .floor))
    private static let wallTexture = SKTexture(imageNamed: MazeTileSource.textureName(for: .wall))
    private static let chestClosedTexture = SKTexture(imageNamed: "ChestClosed")
    private static let chestOpenTexture = SKTexture(imageNamed: "ChestOpen")
    private static let warpTexture = SKTexture(imageNamed: "WarpPortal")
    private static let goalTexture = SKTexture(imageNamed: "GoalFlag")

    private let bumpHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let discoverHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let warpHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let chestHaptic = UINotificationFeedbackGenerator()
    private let goalHaptic = UINotificationFeedbackGenerator()

    // MARK: - Setup

    init(game: MazeGame, traveler: Traveler, event: EventDefinition? = nil) {
        self.game = game
        self.traveler = traveler
        self.todaysEvent = event
        let viewport = CGFloat(Tuning.viewportTiles) * MazeScene.tile
        super.init(size: CGSize(width: viewport, height: viewport))
        // SpriteViewの縦長領域へ追従し、実際の表示領域をカメラ計算へ反映する。
        scaleMode = .resizeFill
        backgroundColor = Palette.background
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMove(to view: SKView) {
        guard cameraNode == nil else { return }
        buildAmbiance()
        buildLight()
        buildPlayer()
        // camera safetyはactual player sprite sizeを使うため、playerを先に作る。
        buildCamera()
        buildVignette()
        applyFog(animated: false)
        // 初期探索範囲にgoalが含まれる場合も、生成直後から同じsolverへ通す。
        refreshViewportGeometry()
        game.noteStopped()
        onHUDUpdate?(makeHUDSnapshot())

        bumpHaptic.prepare()
        discoverHaptic.prepare()
        GameAudio.shared.startBGM()
        GameAudio.shared.startAmbientWind()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        refreshViewportGeometry()
    }

    /// SwiftUIが確定したSpriteViewの実測サイズを初期表示から共有する。
    /// resizeFill任せの通知順序に依存せず、以後の変更もdidChangeSizeと同じ経路へ流す。
    func updateViewportSize(_ viewportSize: CGSize) {
        guard viewportSize.width.isFinite,
              viewportSize.height.isFinite,
              viewportSize.width > 0,
              viewportSize.height > 0 else { return }

        if size != viewportSize {
            size = viewportSize
        } else {
            refreshViewportGeometry()
        }
    }

    /// SwiftUIのlayout完了後に祖先clipを含むactual visible rectで再solveする。
    func updateVisibleViewport() {
        refreshViewportGeometry()
    }

    private func refreshViewportGeometry() {
        guard cameraNode != nil else { return }

        // resizeFill後の実効viewportを正本にし、古いサイズ向けの移動先を残さない。
        cameraNode.removeAllActions()
        cameraNode.position = resolvedCameraPosition(point(for: game.player))
        updateVignette()
    }

    private func makeHUDSnapshot() -> HUDSnapshot {
        HUDSnapshot(mazeSize: game.maze.width,
                   player: game.player,
                   goal: game.maze.goal,
                   explored: game.explored,
                   walked: game.walked,
                   stamina: game.stamina,
                   staminaMax: Tuning.staminaMax,
                   traveler: traveler)
    }

    private func point(for c: Coord) -> CGPoint {
        CGPoint(
            x: (CGFloat(c.x) + 0.5) * Self.tile,
            y: (CGFloat(game.maze.height - 1 - c.y) + 0.5) * Self.tile
        )
    }

    // MARK: - カメラ

    private func buildCamera() {
        let camera = SKCameraNode()
        cameraNode = camera
        camera.position = resolvedCameraPosition(point(for: game.player))
        addChild(camera)
        self.camera = camera
    }

    private var worldSize: CGSize {
        CGSize(width: CGFloat(game.maze.width) * Self.tile,
               height: CGFloat(game.maze.height) * Self.tile)
    }

    private var effectiveViewportSize: CGSize {
        if let view,
           view.bounds.width.isFinite,
           view.bounds.height.isFinite,
           view.bounds.width > 0,
           view.bounds.height > 0 {
            return view.bounds.size
        }
        return size
    }

    /// SKViewがSwiftUI祖先Viewでclipされる場合も含め、window上で本当に見える部分を返す。
    private var actualVisibleViewportRect: CGRect {
        guard let view else { return CGRect(origin: .zero, size: size) }
        return actualVisibleViewportRect(in: view)
    }

    private func actualVisibleViewportRect(in view: SKView) -> CGRect {
        let originalView = view
        // visibleRectは常にcurrentの座標系に属する。各ancestorでparent座標へ
        // 進めたまま保持し、originalView座標へ戻すのは走査完了後の一度だけ。
        var visibleRect = originalView.bounds
        var current: UIView = view

        while let parent = current.superview {
            visibleRect = current.convert(visibleRect, to: parent)
            if parent.clipsToBounds || parent.layer.masksToBounds || parent is UIWindow {
                visibleRect = visibleRect.intersection(parent.bounds)
                guard !visibleRect.isNull, !visibleRect.isEmpty else { return .zero }
            }
            current = parent
        }

        let rectInOriginalView = current.convert(visibleRect, to: originalView)
        return rectInOriginalView.intersection(originalView.bounds)
    }

    private var worldFrame: CGRect {
        CGRect(origin: .zero, size: worldSize)
    }

    private func resolvedCameraPosition(_ playerPosition: CGPoint) -> CGPoint {
        let playerContext = playerContextFrame(at: playerPosition)
        let visibleGoal = visibleNearbyGoalFrame(relativeTo: playerPosition)
        return MazeCameraSafetyGeometry.resolvedPosition(
            playerPosition,
            worldSize: worldSize,
            viewportSize: effectiveViewportSize,
            visibleViewportRect: actualVisibleViewportRect,
            safeInsets: Self.gameplaySafeInsets,
            maximumOutsideWorldReveal: Self.maximumOutsideWorldReveal,
            requiredFrames: [playerContext],
            optionalFrames: visibleGoal.map { [$0] } ?? []
        )
    }

    private func spriteFrame(_ node: SKSpriteNode,
                             at position: CGPoint? = nil,
                             minimumScale: CGFloat = 1) -> CGRect {
        let scaleX = max(abs(node.xScale), minimumScale)
        let scaleY = max(abs(node.yScale), minimumScale)
        let renderedSize = CGSize(width: node.size.width * scaleX,
                                  height: node.size.height * scaleY)
        let position = position ?? node.position
        return CGRect(x: position.x - node.anchorPoint.x * renderedSize.width,
                      y: position.y - node.anchorPoint.y * renderedSize.height,
                      width: renderedSize.width,
                      height: renderedSize.height)
    }

    private func playerContextFrame(at position: CGPoint) -> CGRect {
        let playerFrame = spriteFrame(playerNode, at: position, minimumScale: 1)
        let expanded = playerFrame.insetBy(dx: -Self.playerContextPadding,
                                           dy: -Self.playerContextPadding)
        // world外に存在しない通路文脈までは強制しない。
        let meaningfulContext = expanded.intersection(worldFrame)
        return meaningfulContext.isNull ? playerFrame : meaningfulContext
    }

    private func visibleNearbyGoalFrame(relativeTo playerPosition: CGPoint) -> CGRect? {
        guard game.explored.contains(game.maze.goal), let goalNode else { return nil }
        let goalPosition = goalNode.position
        guard abs(goalPosition.x - playerPosition.x) <= Self.nearbyGoalDistance,
              abs(goalPosition.y - playerPosition.y) <= Self.nearbyGoalDistance else {
            return nil
        }
        // pulse action中の最大scaleを含む完全な旗frameを保護する。
        return spriteFrame(goalNode, minimumScale: Self.goalPulseMaximumScale)
    }

    /// Runtimeとintegration testが同じsafe frameを参照する。
    func gameplaySafeRect(in view: SKView) -> CGRect {
        MazeCameraSafetyGeometry.gameplaySafeRect(viewportBounds: actualVisibleViewportRect,
                                                  insets: Self.gameplaySafeInsets)
    }

    /// Runtimeと同じvisible viewportをintegration testで観測するための読み取り専用窓口。
    /// expected値はtest fixtureの既知frameから独立に算出する。
    func visibleViewportRect(in view: SKView) -> CGRect {
        actualVisibleViewportRect(in: view)
    }

    func projectedPlayerFrame(in view: SKView, includingContext: Bool = false) -> CGRect {
        let sceneFrame = includingContext
            ? playerContextFrame(at: playerNode.position)
            : spriteFrame(playerNode, minimumScale: 1)
        return projectedFrame(sceneFrame, in: view)
    }

    func projectedVisibleGoalFrame(in view: SKView) -> CGRect? {
        guard let goalFrame = visibleNearbyGoalFrame(relativeTo: playerNode.position) else {
            return nil
        }
        return projectedFrame(goalFrame, in: view)
    }

    private func projectedFrame(_ sceneFrame: CGRect, in view: SKView) -> CGRect {
        let corners = [
            CGPoint(x: sceneFrame.minX, y: sceneFrame.minY),
            CGPoint(x: sceneFrame.maxX, y: sceneFrame.minY),
            CGPoint(x: sceneFrame.minX, y: sceneFrame.maxY),
            CGPoint(x: sceneFrame.maxX, y: sceneFrame.maxY),
        ].map { view.convert($0, from: self) }
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - タイルの遅延生成

    private func ensureTile(at c: Coord) {
        guard tileNodes[c] == nil, game.maze.contains(c) else { return }
        let node = game.maze.isWall(c) ? buildWallCell(at: c) : buildFloorCell(at: c)
        tileNodes[c] = node

        // 通路ならギミックも一緒に用意する
        if !game.maze.isWall(c) {
            switch game.maze.gimmick(at: c) {
            case .chest: ensureChest(at: c)
            case .warp:  ensureWarp(at: c)
            case .none:  break
            }
            if c == game.maze.goal { ensureGoal() }
        }
    }

    /// 単色の塗り重ねに使う1x1の白テクスチャ。SKShapeNode(ベクター描画)より
    /// SKSpriteNode+colorBlendFactor の方が大量生成時の負荷が軽いため、
    /// 「石の質感の上に色を乗せる」処理をこちらに統一している。
    private static let solidTexture: SKTexture = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return SKTexture(image: image)
    }()

    private func buildFloorCell(at c: Coord) -> SKNode {
        let container = SKNode()
        container.position = point(for: c)
        container.zPosition = 0
        container.alpha = 0

        let size = CGSize(width: Self.tile - 3, height: Self.tile - 3)

        let texture = SKSpriteNode(texture: Self.croppedTexture(from: Self.floorTexture, for: c))
        texture.size = size
        container.addChild(texture)

        let tint = SKSpriteNode(texture: Self.solidTexture)
        tint.size = size
        tint.color = Palette.floor
        tint.colorBlendFactor = 1.0
        tint.alpha = 0.55   // 下げるほど石の質感が強く出る
        container.addChild(tint)

        addChild(container)
        floorTints[c] = tint
        return container
    }

    private func buildWallCell(at c: Coord) -> SKNode {
        let container = SKNode()
        container.position = point(for: c)
        container.zPosition = 1
        container.alpha = 0

        let size = CGSize(width: Self.tile - 0.5, height: Self.tile - 0.5)

        let texture = SKSpriteNode(texture: Self.croppedTexture(from: Self.wallTexture, for: c))
        texture.size = size
        container.addChild(texture)

        let tint = SKSpriteNode(texture: Self.solidTexture)
        tint.size = size
        tint.color = Palette.wall
        tint.colorBlendFactor = 1.0
        tint.alpha = 0.72
        container.addChild(tint)

        addChild(container)
        return container
    }

    /// 大きな1枚の素材から、マスごとに少しずつ違う場所を切り出す。
    /// 画像全体を1マスに縮小すると模様が潰れて泥のように見えるため。
    private static func croppedTexture(from base: SKTexture, for coord: Coord) -> SKTexture {
        let sourceSize = base.size()
        guard sourceSize.width > 1, sourceSize.height > 1 else { return base }

        let sampleSize: CGFloat = 260
        let stepX = sampleSize * 0.37
        let stepY = sampleSize * 0.37
        let maxX = max(sourceSize.width - sampleSize, 1)
        let maxY = max(sourceSize.height - sampleSize, 1)
        let originX = (CGFloat(coord.x) * stepX).truncatingRemainder(dividingBy: maxX)
        let originY = (CGFloat(coord.y) * stepY).truncatingRemainder(dividingBy: maxY)

        let rect = CGRect(
            x: originX / sourceSize.width,
            y: originY / sourceSize.height,
            width: min(sampleSize / sourceSize.width, 1),
            height: min(sampleSize / sourceSize.height, 1)
        )
        return SKTexture(rect: rect, in: base)
    }

    // MARK: - ギミック

    private func ensureChest(at c: Coord) {
        guard chestNodes[c] == nil else { return }
        let node = SKSpriteNode(texture: Self.chestClosedTexture)
        let side = Self.tile * 0.62
        node.size = CGSize(width: side, height: side)
        node.position = point(for: c)
        node.zPosition = 2
        node.alpha = 0
        addChild(node)
        chestNodes[c] = node
    }

    private func ensureWarp(at c: Coord) {
        guard warpNodes[c] == nil else { return }
        let node = SKSpriteNode(texture: Self.warpTexture)
        let side = Self.tile * 0.58
        node.size = CGSize(width: side, height: side)
        node.position = point(for: c)
        node.zPosition = 2
        node.alpha = 0
        node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4.2)), withKey: "spin")
        addChild(node)
        warpNodes[c] = node
    }

    private func ensureGoal() {
        guard goalNode == nil else { return }
        let node = SKSpriteNode(texture: Self.goalTexture)
        let height = Self.tile * 0.85
        let aspect = Self.goalTexture.size().width / max(Self.goalTexture.size().height, 1)
        node.size = CGSize(width: height * aspect, height: height)
        node.position = point(for: game.maze.goal)
        node.zPosition = 3
        node.alpha = 0
        node.run(.repeatForever(.sequence([
            .scale(to: 1.10, duration: 1.1),
            .scale(to: 0.96, duration: 1.1),
        ])), withKey: "pulse")
        addChild(node)
        goalNode = node
    }

    // MARK: - 雰囲気

    private func buildAmbiance() {
        let worldW = CGFloat(game.maze.width) * Self.tile
        let worldH = CGFloat(game.maze.height) * Self.tile

        for _ in 0..<24 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...2.0))
            mote.fillColor = Palette.firefly
            mote.strokeColor = .clear
            mote.blendMode = .add
            mote.alpha = CGFloat.random(in: 0.12...0.26)
            mote.zPosition = 0.5
            mote.position = CGPoint(x: CGFloat.random(in: 0...worldW),
                                    y: CGFloat.random(in: 0...worldH))
            addChild(mote)

            let dx = CGFloat.random(in: -18...18)
            let dy = CGFloat.random(in: -18...18)
            let duration = TimeInterval.random(in: 3.5...6.5)
            mote.run(.repeatForever(.sequence([
                .moveBy(x: dx, y: dy, duration: duration),
                .moveBy(x: -dx, y: -dy, duration: duration),
            ])))
            mote.run(.repeatForever(.sequence([
                .fadeAlpha(to: mote.alpha * 0.3, duration: duration * 0.5),
                .fadeAlpha(to: mote.alpha, duration: duration * 0.5),
            ])))
        }
    }

    private func buildLight() {
        let diameter = Self.tile * CGFloat(Tuning.sightSteps * 2 + 3)
        glowNode = SKSpriteNode(texture: MazeScene.glowTexture(diameter: diameter, color: Palette.lamp))
        glowNode.size = CGSize(width: diameter, height: diameter)
        glowNode.blendMode = .add
        glowNode.zPosition = 5
        glowNode.position = point(for: game.player)
        addChild(glowNode)
    }

    private func buildPlayer() {
        playerNode = SKSpriteNode(texture: SKTexture(imageNamed: traveler.imageName))
        let side = Self.tile * 0.92
        playerNode.size = CGSize(width: side, height: side)
        playerNode.position = point(for: game.player)
        playerNode.zPosition = 6
        addChild(playerNode)
    }

    private func buildVignette() {
        let node = SKSpriteNode()
        node.position = .zero
        node.zPosition = 20
        cameraNode.addChild(node)
        vignetteNode = node
        updateVignette()
    }

    private func updateVignette() {
        guard let vignetteNode, size.width > 0, size.height > 0 else { return }
        vignetteNode.texture = MazeScene.vignetteTexture(size: size)
        vignetteNode.size = size
        vignetteNode.position = .zero
    }

    private static func glowTexture(diameter: CGFloat, color: UIColor) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let colors = [
                color.withAlphaComponent(0.34).cgColor,
                color.withAlphaComponent(0.10).cgColor,
                color.withAlphaComponent(0.0).cgColor,
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors,
                                            locations: [0.0, 0.45, 1.0]) else { return }
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            cg.drawRadialGradient(gradient,
                                  startCenter: center, startRadius: 0,
                                  endCenter: center, endRadius: diameter / 2,
                                  options: [])
        }
        return SKTexture(image: image)
    }

    private static func vignetteTexture(size: CGSize) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let colors = [
                UIColor.black.withAlphaComponent(0.0).cgColor,
                UIColor.black.withAlphaComponent(0.0).cgColor,
                UIColor.black.withAlphaComponent(0.38).cgColor,
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors,
                                            locations: [0.0, 0.62, 1.0]) else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            cg.drawRadialGradient(gradient,
                                  startCenter: center, startRadius: 0,
                                  endCenter: center, endRadius: max(size.width, size.height) * 0.72,
                                  options: [])
        }
        return SKTexture(image: image)
    }

    // MARK: - 霧

    private func fogAlpha(for coord: Coord, isWall: Bool) -> CGFloat {
        if game.visible.contains(coord) { return Tuning.alphaVisible }
        if game.explored.contains(coord) {
            return isWall ? Tuning.alphaExploredWall : Tuning.alphaExploredFloor
        }
        return 0
    }

    /// fadeAlpha を専用のキーで走らせるので、回転や脈動など他のアクションを止めない。
    private func setFogAlpha(_ target: CGFloat, on node: SKNode?, animated: Bool) {
        guard let node, abs(node.alpha - target) > 0.005 else { return }
        if animated {
            node.run(.fadeAlpha(to: target, duration: Tuning.fogFadeDuration), withKey: "fog")
        } else {
            node.removeAction(forKey: "fog")
            node.alpha = target
        }
    }

    private func applyFog(animated: Bool) {
        // 見えたことのあるマスだけノードを用意する
        for coord in game.explored { ensureTile(at: coord) }

        for (coord, node) in tileNodes {
            let isWall = game.maze.isWall(coord)
            if !isWall, let tint = floorTints[coord] {
                tint.color = game.walked.contains(coord) ? Palette.walked : Palette.floor
            }
            setFogAlpha(fogAlpha(for: coord, isWall: isWall), on: node, animated: animated)
        }
        for (coord, node) in chestNodes {
            setFogAlpha(fogAlpha(for: coord, isWall: false), on: node, animated: animated)
        }
        for (coord, node) in warpNodes {
            setFogAlpha(fogAlpha(for: coord, isWall: false), on: node, animated: animated)
        }
        setFogAlpha(fogAlpha(for: game.maze.goal, isWall: false), on: goalNode, animated: animated)
    }

    // MARK: - 入力

    func receive(direction: Direction) {
        guard !isWalking, !finished else { return }
        game.noteSwipe(direction: direction)

        let route = game.plan(direction: direction)
        guard !route.isEmpty else {
            bump(direction)
            game.noteStopped()
            return
        }
        isWalking = true
        walk(route: route, index: 0)
    }

    private func walk(route: [RouteStep], index: Int) {
        guard index < route.count else {
            finishWalkingIfNeeded()
            return
        }
        let step = route[index]
        let (newly, chestOpened) = game.advance(to: step.coord, arrivedByWarp: step.arrivedByWarp)
        onHUDUpdate?(makeHUDSnapshot())
        let destination = point(for: step.coord)
        // 新たに見えたgoal nodeも同じcamera solveへ含められるよう、先に生成する。
        applyFog(animated: true)

        if step.arrivedByWarp {
            performWarpJump(to: destination)
        } else {
            playerNode.run(.move(to: destination, duration: Tuning.stepDuration))
            glowNode.run(.move(to: destination, duration: Tuning.stepDuration))
            cameraNode.run(.move(to: resolvedCameraPosition(destination), duration: Tuning.stepDuration))
        }

        if step.arrivedByWarp {
            GameAudio.shared.play(.warp, in: self)
        } else {
            GameAudio.shared.playFootstepIfNeeded(in: self)
        }

        if chestOpened {
            openChestEffect(at: step.coord)
        } else if newly.count >= Tuning.discoveryThreshold {
            if Tuning.hapticsEnabled { discoverHaptic.impactOccurred(intensity: 0.45) }
            GameAudio.shared.play(.discovery, in: self)
        }

        if step.coord == game.maze.eventCoord,
           game.eventOutcome == nil,
           !pendingEventShown,
           let todaysEvent {
            pendingEventShown = true
            onEventTrigger?(todaysEvent)
        }

        let wait = step.arrivedByWarp ? Tuning.warpFadeDuration * 2 : Tuning.stepDuration
        // 体力が0になったマスの移動アニメーションまでは見せて、そこで終了する。
        // ただしワープ入口で0になった場合は、無消費の出口移動まで解決してから止める。
        let nextIsWarpExit = route.indices.contains(index + 1) && route[index + 1].arrivedByWarp
        let shouldFinish = game.isCleared || (game.isExhausted && !nextIsWarpExit)
        run(.sequence([
            .wait(forDuration: wait),
            .run { [weak self] in
                guard let self else { return }
                if shouldFinish {
                    self.finishWalkingIfNeeded()
                } else {
                    self.walk(route: route, index: index + 1)
                }
            },
        ]))
    }

    private func finishWalkingIfNeeded() {
        isWalking = false
        game.noteStopped()
        // ゴールと体力0が同じマスなら、到達した事実を優先する。
        if game.isCleared {
            checkGoal()
        } else if game.isExhausted {
            finishNow()
        }
    }

    private func bump(_ direction: Direction) {
        if Tuning.hapticsEnabled { bumpHaptic.impactOccurred(intensity: 0.7) }
        GameAudio.shared.play(.bump, in: self)
        let offset = CGPoint(x: CGFloat(direction.dx) * Self.tile * 0.16,
                             y: CGFloat(-direction.dy) * Self.tile * 0.16)
        playerNode.run(.sequence([
            .moveBy(x: offset.x, y: offset.y, duration: 0.055),
            .moveBy(x: -offset.x, y: -offset.y, duration: 0.11),
        ]), withKey: "bump")
    }

    private func performWarpJump(to destination: CGPoint) {
        if Tuning.hapticsEnabled { warpHaptic.impactOccurred(intensity: 0.85) }
        for node in [playerNode as SKNode, glowNode as SKNode] {
            node.run(.sequence([
                .group([.fadeAlpha(to: 0.12, duration: Tuning.warpFadeDuration),
                        .scale(to: 0.5, duration: Tuning.warpFadeDuration)]),
                .run { node.position = destination },
                .group([.fadeAlpha(to: 1.0, duration: Tuning.warpFadeDuration),
                        .scale(to: 1.0, duration: Tuning.warpFadeDuration)]),
            ]), withKey: "warp")
        }
        let cameraDestination = resolvedCameraPosition(destination)
        cameraNode.run(.sequence([
            .wait(forDuration: Tuning.warpFadeDuration),
            .run { [weak self] in self?.cameraNode.position = cameraDestination },
        ]), withKey: "warp")
    }

    private func openChestEffect(at coord: Coord) {
        if Tuning.hapticsEnabled { chestHaptic.notificationOccurred(.success) }
        GameAudio.shared.play(.chest, in: self)

        if let node = chestNodes[coord] {
            node.texture = Self.chestOpenTexture
            node.run(.sequence([
                .scale(to: 1.18, duration: 0.16),
                .scale(to: 1.0, duration: 0.22),
            ]))
        }

        let origin = point(for: coord)
        let burst = SKSpriteNode(texture: MazeScene.glowTexture(diameter: Self.tile * 3.2,
                                                               color: Palette.chestGlow))
        burst.position = origin
        burst.blendMode = .add
        burst.zPosition = 4
        burst.alpha = 0.9
        burst.setScale(0.3)
        addChild(burst)
        burst.run(.sequence([
            .group([.scale(to: 1.3, duration: Tuning.chestRevealDuration),
                    .fadeAlpha(to: 0, duration: Tuning.chestRevealDuration)]),
            .removeFromParent(),
        ]))

        for _ in 0..<6 {
            let spark = SKShapeNode(circleOfRadius: 2.2)
            spark.fillColor = Palette.chestGlow
            spark.strokeColor = .clear
            spark.blendMode = .add
            spark.position = origin
            spark.zPosition = 4
            addChild(spark)

            let angle = CGFloat.random(in: 0..<(.pi * 2))
            let dist = CGFloat.random(in: 14...30)
            spark.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * dist, y: sin(angle) * dist,
                            duration: Tuning.chestRevealDuration),
                    .fadeAlpha(to: 0, duration: Tuning.chestRevealDuration),
                    .scale(to: 0.3, duration: Tuning.chestRevealDuration),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    private func checkGoal() {
        guard game.isCleared, !finished else { return }
        finished = true
        if Tuning.hapticsEnabled { goalHaptic.notificationOccurred(.success) }
        GameAudio.shared.play(.goal, in: self)
        GameAudio.shared.stopAmbience()

        glowNode.run(.sequence([
            .scale(to: 3.2, duration: 0.7),
            .fadeAlpha(to: 0, duration: 0.3),
        ]))

        let log = game.makeLog()
        run(.sequence([
            .wait(forDuration: 0.85),
            .run { [weak self] in self?.onPausePoint?(log) },
        ]))
    }

    /// 「ここまでにする」で外部から一時停止させる。
    func finishNow() {
        guard !finished else { return }
        finished = true
        removeAllActions()
        isWalking = false
        GameAudio.shared.stopAmbience(fadeDuration: 0.6)
        onPausePoint?(game.makeLog())
    }

    /// 一時停止画面で「今日はここまで見る」が選ばれたときだけ確定する。
    func commitFinish() {
        guard finished, let onFinish else { return }
        self.onFinish = nil   // 二重タップでも結果確定を一度だけにする
        onFinish(game.makeLog())
    }

    /// イベントの選択肢が選ばれたときに呼ぶ。二重選択時は状態も音も変えない。
    @discardableResult
    func resolveEventChoice(index: Int) -> Bool {
        guard let todaysEvent, game.resolveEvent(todaysEvent, choiceIndex: index) else {
            return false
        }
        pendingEventShown = false
        GameAudio.shared.play(.uiTap, in: self)
        return true
    }

    /// 広告視聴成功後、位置・霧・軌跡を保ったまま探索を再開する。
    @discardableResult
    func resumeAfterAd(ignoringLimit: Bool = false) -> Bool {
        guard finished, game.refillStaminaForReplay(ignoringLimit: ignoringLimit) else { return false }
        finished = false

        // ゴール演出の拡大→消灯が残ると手元が暗くなるため、必ず通常状態へ戻す。
        glowNode.removeAllActions()
        glowNode.setScale(1.0)
        glowNode.alpha = 1.0
        glowNode.position = point(for: game.player)

        GameAudio.shared.startBGM()
        GameAudio.shared.startAmbientWind()
        onHUDUpdate?(makeHUDSnapshot())
        return true
    }

    /// 広告視聴成功後、今日歩いた分の表示と記録をスタート地点まで巻き戻す。
    /// 「続きから」と同じ広告上限を使い、上限到達後の呼び出しは何も変えない。
    @discardableResult
    func restartAfterAd(ignoringLimit: Bool = false) -> Bool {
        guard finished, game.resetForRestart(ignoringLimit: ignoringLimit) else { return false }
        finished = false
        isWalking = false
        pendingEventShown = false

        // 過去に生成したノードは再利用し、探索前の霧へ戻す。
        for node in tileNodes.values {
            node.removeAction(forKey: "fog")
            node.alpha = 0
        }

        // 開封演出が残っていても、閉じた宝箱へ確実に戻す。
        for node in chestNodes.values {
            node.removeAllActions()
            node.texture = Self.chestClosedTexture
            node.alpha = 0
            node.setScale(1.0)
        }
        for node in warpNodes.values { node.alpha = 0 }
        goalNode?.alpha = 0

        let start = point(for: game.player)
        playerNode.removeAllActions()
        playerNode.position = start
        playerNode.alpha = 1
        playerNode.setScale(1.0)

        glowNode.removeAllActions()
        glowNode.position = start
        glowNode.alpha = 1
        glowNode.setScale(1.0)

        cameraNode.removeAllActions()
        cameraNode.position = resolvedCameraPosition(start)

        applyFog(animated: false)
        game.noteStopped()
        GameAudio.shared.startBGM()
        GameAudio.shared.startAmbientWind()
        onHUDUpdate?(makeHUDSnapshot())
        return true
    }
}
