import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 訪問に添えた写真の保管。
///
/// 画像の実体は Application Support に置き、SwiftData には**ファイル名だけ**を持たせる。
/// 原寸を CloudKit へ流すとユーザーの iCloud 容量と通信量を圧迫するため、
/// 同期対象にするのは長辺 512px のサムネイルに限る。
enum PhotoStore {

    enum StoreError: LocalizedError {
        case writeFailed
        case unreadableImage

        var errorDescription: String? {
            switch self {
            case .writeFailed: "写真を保存できませんでした。"
            case .unreadableImage: "この画像を読み込めませんでした。"
            }
        }
    }

    /// サムネイルの長辺。一覧描画に足りて、同期しても軽い大きさ。
    static let thumbnailMaxPixel = 512

    static var directory: URL {
        let url = URL.applicationSupportDirectory.appending(path: "Photos", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    // MARK: - 保存

    /// 原寸をファイルへ、サムネイルを Data として返す。
    static func save(_ data: Data) throws -> (fileName: String, thumbnail: Data?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw StoreError.unreadableImage
        }

        let fileName = "\(UUID().uuidString).\(fileExtension(for: source))"

        do {
            try data.write(to: url(for: fileName), options: .atomic)
        } catch {
            throw StoreError.writeFailed
        }

        return (fileName, makeThumbnail(from: source))
    }

    static func loadData(fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    /// モデルを消すだけではファイルが残るため、削除の経路では必ずこれも呼ぶ。
    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// 保管している写真の合計バイト数。設定画面で使用量を出すために使う。
    static func totalBytes() -> Int64 {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        return contents.reduce(into: Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
    }

    // MARK: - サムネイル

    /// `CGImageSourceCreateThumbnailAtIndex` は原寸を丸ごと展開せずに縮小するため、
    /// 大きな写真を続けて取り込んでもメモリが跳ねない。
    static func makeThumbnail(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return makeThumbnail(from: source)
    }

    private static func makeThumbnail(from source: CGImageSource) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixel,
        ]

        guard
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            let output = CFDataCreateMutable(nil, 0),
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private static func fileExtension(for source: CGImageSource) -> String {
        guard
            let identifier = CGImageSourceGetType(source) as String?,
            let type = UTType(identifier),
            let preferred = type.preferredFilenameExtension
        else {
            return "jpg"
        }
        return preferred
    }
}
