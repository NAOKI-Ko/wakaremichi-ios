import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue:  CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// 深い藍〜黒の地に、ランプのような暖色の光。
enum Palette {
    static let background = UIColor(hex: 0x080C16)
    static let surface    = UIColor(hex: 0x121A2B)
    static let floor      = UIColor(hex: 0x27324A)
    static let walked     = UIColor(hex: 0x3E4260)
    static let wall       = UIColor(hex: 0x11172A)
    static let wallEdge   = UIColor(hex: 0x1B2340)
    static let lamp       = UIColor(hex: 0xFFC98A)
    static let goal       = UIColor(hex: 0xFFB347)
    static let chestGlow  = UIColor(hex: 0xFFD68A)
    static let firefly    = UIColor(hex: 0xFFDDA6)

    static var backgroundSUI: Color { Color(background) }
    static var surfaceSUI: Color    { Color(surface) }
    static var lampSUI: Color       { Color(lamp) }
    static var goalSUI: Color       { Color(goal) }
    static var floorSUI: Color      { Color(floor) }
}
