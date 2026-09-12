import SwiftUI

/// 地図上の1本のピン。
///
/// チェックインすると `place.visitCount` が変わり、この View が
/// 灰色の中抜きから朱色の塗りへ 0.4 秒で切り替わって一度だけ弾む。
/// このアプリで一番手触りが出る箇所なので、遷移はここに集約している。
struct PlacePinView: View {
    let place: Place
    var isSelected: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: PlacePinState { PlacePinState(place: place) }
    private var diameter: CGFloat { 34 }

    var body: some View {
        ZStack {
            if state.hasHalo {
                Circle()
                    .fill(state.tint.opacity(0.22))
                    .frame(width: diameter + 10, height: diameter + 10)
            }

            Circle()
                .fill(state.isFilled ? state.tint : Color.pinSurface)
                .overlay {
                    Circle()
                        .strokeBorder(state.tint, lineWidth: state.isFilled ? 0 : 2.5)
                }
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

            symbol
        }
        .scaleEffect(isSelected ? 1.22 : 1)
        .animation(transition, value: place.visitCount)
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(place.name)、\(state.label)")
    }

    @ViewBuilder
    private var symbol: some View {
        if let badge = state.badgeText {
            Text(badge)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.pinLabel)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(state.isFilled ? Color.pinLabel : state.tint)
        }
    }

    private var iconName: String {
        switch state {
        case .wishlisted: "star.fill"
        default: place.category.symbolName
        }
    }

    /// 「動きを減らす」が有効なときは弾ませず、クロスフェードに落とす。
    private var transition: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.25)
            : .spring(response: 0.4, dampingFraction: 0.55)
    }
}

/// プレビュー用に、指定した状態の Place を組み立てる。
private func previewPlace(name: String, wishLevel: Int, visitCount: Int, visitedToday: Bool = false) -> Place {
    let place = Place(
        name: name,
        coordinate: .init(latitude: 35, longitude: 139),
        category: .food,
        wishLevel: wishLevel
    )
    let calendar = Calendar.current
    place.visits = (0..<visitCount).map { index in
        let date = (visitedToday && index == 0)
            ? Date.now
            : (calendar.date(byAdding: .day, value: -30 * (index + 1), to: .now) ?? .now)
        return Visit(visitedAt: date)
    }
    return place
}

#Preview("ピンの5状態", traits: .sizeThatFitsLayout) {
    HStack(spacing: 22) {
        PlacePinView(place: previewPlace(name: "未訪問", wishLevel: 0, visitCount: 0))
        PlacePinView(place: previewPlace(name: "優先", wishLevel: 3, visitCount: 0))
        PlacePinView(place: previewPlace(name: "訪問済み", wishLevel: 0, visitCount: 1))
        PlacePinView(place: previewPlace(name: "常連", wishLevel: 0, visitCount: 5))
        PlacePinView(place: previewPlace(name: "本日", wishLevel: 0, visitCount: 1, visitedToday: true))
    }
    .padding(30)
}
