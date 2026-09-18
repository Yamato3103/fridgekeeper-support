import SwiftUI
import UIKit

/// アプリ共通の色。
///
/// Asset Catalog でも定義できるが、ピンの配色は仕様書と1対1で対応させたいので
/// 値をコードに置いて追いやすくしてある。ライト／ダークの両方を明示的に指定する。
///
/// `ShapeStyle` への制約付き extension として定義しているため、
/// `Color.pinVisited` と `.foregroundStyle(.pinVisited)` の両方の書き方ができる。
extension ShapeStyle where Self == Color {

    /// 訪問済みのピン。地図上で唯一の彩度の高い色として使う。
    static var pinVisited: Color { Color(light: 0xB2_3A_22, dark: 0xE4_76_5A) }

    /// 行きたい度の高い未訪問スポット。
    static var pinWishlisted: Color { Color(light: 0x8A_64_10, dark: 0xD9_AC_4C) }

    /// 通常の未訪問スポット。彩度を落とし、訪問済みとの差を明確にする。
    static var pinIdle: Color { Color(light: 0x6F_81_75, dark: 0x85_91_83) }

    /// 中抜きピンの地の色。
    static var pinSurface: Color { Color(light: 0xFA_FB_F8, dark: 0x23_2B_22) }

    /// 塗りピンの上に乗る記号・数字の色。
    static var pinLabel: Color { Color(light: 0xFA_FB_F8, dark: 0x11_15_0F) }
}

extension Color {
    /// ライト／ダークで別の値を持つ色を、16進数リテラルから作る。
    init(light: UInt32, dark: UInt32) {
        self = Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
