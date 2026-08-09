import SwiftUI
import UIKit

/// ResultViewが確定済みの値を渡す、共有専用の不変データ。
/// streakの再計算や取得物の再抽選はここでは行わない。
struct ShareCardContent: Equatable {
    let date: Date
    let travelerName: String
    let travelerImageName: String
    let diagnosisTitle: String
    let currentStreak: Int
    let keepsakeName: String?
    let reachedGoal: Bool
    let steps: Int
    let explorationPercent: Int
    let chestCount: Int

    init(log: RunLog,
         archetype: Archetype,
         traveler: Traveler,
         date: Date,
         currentStreak: Int,
         keepsake: Keepsake?) {
        self.date = date
        self.travelerName = traveler.displayName
        self.travelerImageName = traveler.imageName
        self.diagnosisTitle = archetype.fullName
        self.currentStreak = log.reachedGoal ? max(0, currentStreak) : 0
        self.keepsakeName = log.reachedGoal ? keepsake?.name : nil
        self.reachedGoal = log.reachedGoal
        self.steps = log.steps
        if log.openCellCount > 0 {
            let percent = Int((Double(log.exploredCellCount)
                               / Double(log.openCellCount) * 100).rounded())
            self.explorationPercent = min(100, max(0, percent))
        } else {
            self.explorationPercent = 0
        }
        self.chestCount = log.chestOpened ? 1 : 0
    }

    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日の旅"
        return formatter.string(from: date)
    }
}

/// 共有画像だけのpureなView。完全な迷路や軌跡座標は入力にも持たない。
struct ShareCardView: View {

    static let cardSize = CGSize(width: 640, height: 800)

    let content: ShareCardContent

    var body: some View {
        ZStack {
            Palette.backgroundSUI

            Image("ShareCardBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .opacity(0.72)

            RadialGradient(colors: [Palette.lampSUI.opacity(0.13), .clear],
                           center: .center,
                           startRadius: 10,
                           endRadius: 330)

            VStack(spacing: 0) {
                Text("まいにちの分かれ道")
                    .font(.system(size: 18, weight: .medium))
                    .kerning(4)
                    .foregroundStyle(Palette.lampSUI.opacity(0.82))
                    .padding(.top, 58)

                Text(content.dateText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 10)

                Image("DividerOrnament")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 24)
                    .opacity(0.48)
                    .padding(.vertical, 27)

                VStack(spacing: 10) {
                    Text("今日の旅人")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.42))

                    Image(content.travelerImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 92)

                    Text(content.travelerName)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.52))

                    Text("「\(content.diagnosisTitle)」")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }

                if content.currentStreak > 0 {
                    Text("\(content.currentStreak)日目の旅")
                        .font(.system(size: 15, weight: .medium))
                        .kerning(2)
                        .foregroundStyle(Palette.lampSUI.opacity(0.78))
                        .padding(.top, 26)
                } else if !content.reachedGoal {
                    Text("今日はここまで")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(.top, 26)
                }

                if let keepsakeName = content.keepsakeName {
                    VStack(spacing: 6) {
                        Text("今日、持ち帰ったもの")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("「\(keepsakeName)」")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Palette.lampSUI.opacity(0.82))
                    }
                    .padding(.top, 24)
                }

                Spacer(minLength: 24)

                HStack(spacing: 46) {
                    stat("探索率", "\(content.explorationPercent)%")
                    stat("歩いたマス", "\(content.steps)")
                    stat("宝箱", "\(content.chestCount)個")
                }

                Text("今日の灯りを、そっと持ち帰る")
                    .font(.system(size: 11))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.28))
                    .padding(.top, 35)
                    .padding(.bottom, 45)
            }
            .padding(.horizontal, 58)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 7) {
            Text(value)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.38))
        }
        .frame(minWidth: 105)
    }
}

/// SwiftUIの共有専用Viewを、端末サイズに依存しないUIImageへ書き出す。
@MainActor
enum ShareImageRenderer {
    static func render(content: ShareCardContent) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content))
        renderer.proposedSize = ProposedViewSize(width: ShareCardView.cardSize.width,
                                                 height: ShareCardView.cardSize.height)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
