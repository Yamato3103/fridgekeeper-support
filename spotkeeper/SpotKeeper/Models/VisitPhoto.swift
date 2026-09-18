import Foundation
import SwiftData

/// 訪問に添えた写真。
///
/// 画像の実体はアプリのファイル領域に置き、モデルにはファイル名だけを持たせる。
/// 原寸を CloudKit へ流すとユーザーの iCloud 容量と通信量を圧迫するため、
/// 既定の同期対象はサムネイル（数十KB）のみとする。
@Model
final class VisitPhoto {
    var id: UUID = UUID()

    /// `PhotoStore.photosDirectory` からの相対ファイル名。
    var fileName: String = ""

    /// 一覧描画用のサムネイル。長辺 512px 相当。
    var thumbnailData: Data?

    /// 撮影日時と撮影位置。写真からの訪問サジェスト（V1.1）で使う。
    var capturedAt: Date?
    var latitude: Double?
    var longitude: Double?

    var createdAt: Date = Date()

    var visit: Visit?

    init(
        fileName: String,
        thumbnailData: Data? = nil,
        capturedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.thumbnailData = thumbnailData
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = .now
    }
}
