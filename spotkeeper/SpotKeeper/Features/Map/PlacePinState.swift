import SwiftUI

/// 地図上のピンが取りうる5つの状態。仕様書03章「ピンの状態設計」に対応する。
///
/// 色だけでなく「中抜き／塗り」の形状差も併用している。
/// 色覚特性への配慮であると同時に、地図を縮小したときの判別性が上がるため。
enum PlacePinState: Equatable {
    /// 未訪問。
    case unvisited
    /// 未訪問かつ行きたい度が高い。
    case wishlisted
    /// 訪問1回。
    case visited
    /// 訪問2回以上。回数バッジを出す。
    case regular(count: Int)
    /// 本日訪問。チェックイン直後の状態。
    case visitedToday

    init(place: Place) {
        if place.isVisitedToday {
            self = .visitedToday
        } else if place.visitCount >= 2 {
            self = .regular(count: place.visitCount)
        } else if place.visitCount == 1 {
            self = .visited
        } else if place.wishLevel >= 2 {
            self = .wishlisted
        } else {
            self = .unvisited
        }
    }

    /// 円を塗りつぶすか、輪郭だけにするか。
    var isFilled: Bool {
        switch self {
        case .unvisited, .wishlisted: false
        case .visited, .regular, .visitedToday: true
        }
    }

    var tint: Color {
        switch self {
        case .unvisited: .pinIdle
        case .wishlisted: .pinWishlisted
        case .visited, .regular, .visitedToday: .pinVisited
        }
    }

    /// 訪問済みのピンにだけ添える淡いリング。常連であることが遠目にも分かる。
    var hasHalo: Bool {
        switch self {
        case .regular, .visitedToday: true
        default: false
        }
    }

    var badgeText: String? {
        if case let .regular(count) = self { return String(count) }
        return nil
    }

    var label: String {
        switch self {
        case .unvisited: "未訪問"
        case .wishlisted: "未訪問・優先"
        case .visited: "訪問済み"
        case let .regular(count): "訪問\(count)回"
        case .visitedToday: "本日訪問"
        }
    }
}
