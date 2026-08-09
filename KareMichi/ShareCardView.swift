import SwiftUI
import UIKit

/// 共有用の画像。ネタバレなし(迷路の壁・道しるべの文章・診断の詳細は含めない)。
/// 軌跡の線画+称号+日付だけの、Wordleのブロックと同じ発想。
struct ShareCardView: View {

    let log: RunLog
    let archetype: Archetype
    let traveler: Traveler
    let date: Date

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.M.d"
        return f.string(from: date)
    }

    var body: some View {
        ZStack {
            Palette.backgroundSUI
            Image("ShareCardBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()

            VStack(spacing: 22) {
                Text("まいにちの分かれ道")
                    .font(.system(size: 13, weight: .medium))
                    .kerning(2)
                    .foregroundStyle(Palette.lampSUI.opacity(0.7))
                    .padding(.top, 30)

                TrailShape(points: log.path, columns: Tuning.mazeSize, rows: Tuning.mazeSize)
                    .stroke(Palette.lampSUI.opacity(0.18),
                           style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .overlay(
                        TrailShape(points: log.path, columns: Tuning.mazeSize, rows: Tuning.mazeSize)
                            .stroke(Palette.lampSUI,
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    )
                    .padding(.horizontal, 44)
                    .aspectRatio(1, contentMode: .fit)

                VStack(spacing: 8) {
                    Image(traveler.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 56)

                    Text(archetype.fullName)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))

                    Text(dateText)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 36)
        }
        .frame(width: 640, height: 800)
    }
}

/// SwiftUIビューをUIImageに書き出すヘルパー。iOS 16+ の ImageRenderer を使う。
@MainActor
enum ShareImageRenderer {
    static func render(log: RunLog, archetype: Archetype, traveler: Traveler, date: Date) -> UIImage? {
        let view = ShareCardView(log: log, archetype: archetype, traveler: traveler, date: date)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0   // Retina相当の解像度で書き出す
        return renderer.uiImage
    }
}
