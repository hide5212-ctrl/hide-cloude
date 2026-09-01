import SwiftUI
import UIKit

/// Web 版（index.html）と同じ配色。ライト / ダークで自動的に切り替わる。
enum Palette {
    static let bg          = dynamic(light: 0xEDEFEA, dark: 0x11161B)
    static let surface     = dynamic(light: 0xFFFFFF, dark: 0x1A2129)
    static let surface2    = dynamic(light: 0xF6F7F3, dark: 0x212A33)
    static let ink         = dynamic(light: 0x161F27, dark: 0xE8ECEF)
    static let muted       = dynamic(light: 0x6D7883, dark: 0x93A0AB)
    static let line        = dynamic(light: 0xD8DCD4, dark: 0x2B343D)
    static let line2       = dynamic(light: 0xC2C8BE, dark: 0x3A4550)
    static let accent      = dynamic(light: 0x1E5A7A, dark: 0x79B6D4)
    static let accentSoft  = dynamic(light: 0xDEE9EF, dark: 0x1C3241)
    static let pin         = dynamic(light: 0xAE4238, dark: 0xE48B81)
    static let pinSoft     = dynamic(light: 0xF7E5E2, dark: 0x3A2320)
    static let desk        = dynamic(light: 0xCDC3B1, dark: 0x3B372F)
    static let desk2       = dynamic(light: 0xB7AC96, dark: 0x4E4939)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum Typeface {
    /// 見出しは明朝体。iOS に標準で入っているヒラギノ明朝を使い、
    /// 見つからない環境ではシステム書体にフォールバックする。
    static func mincho(_ size: CGFloat) -> Font {
        if UIFont(name: "HiraMinProN-W6", size: size) != nil {
            return .custom("HiraMinProN-W6", size: size)
        }
        return .system(size: size, weight: .semibold, design: .serif)
    }
}
