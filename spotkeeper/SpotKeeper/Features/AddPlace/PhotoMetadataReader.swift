import CoreLocation
import Foundation
import ImageIO
import Photos
import PhotosUI

/// 写真から撮影位置と撮影日時を読む。
///
/// V1 ではスポット登録の入口として使い、V1.1 の「写真からの訪問サジェスト」でも
/// 同じ処理を使い回す。
///
/// 取得経路は2つ用意している。PhotosPicker が返す画像データからは
/// 位置情報が落ちていることがあるため、その場合に限り PhotoKit へ回る。
/// PhotoKit は写真ライブラリへの許可が要るので、先に許可の要らない EXIF を試す。
enum PhotoMetadataReader {

    struct Metadata {
        var coordinate: CLLocationCoordinate2D
        var capturedAt: Date?
    }

    static func read(from item: PhotosPickerItem) async -> Metadata? {
        if let data = try? await item.loadTransferable(type: Data.self),
           let metadata = readEXIF(from: data) {
            return metadata
        }

        if let identifier = item.itemIdentifier {
            return readFromPhotoLibrary(localIdentifier: identifier)
        }

        return nil
    }

    /// 画像データの EXIF / GPS タグから読む。写真ライブラリの許可は不要。
    static func readEXIF(from data: Data) -> Metadata? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
            let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
            let longitude = gps[kCGImagePropertyGPSLongitude] as? Double
        else {
            return nil
        }

        // GPS タグの緯度経度は絶対値。南緯・西経は Ref で表される。
        let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
        let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"

        let coordinate = CLLocationCoordinate2D(
            latitude: latitudeRef == "S" ? -latitude : latitude,
            longitude: longitudeRef == "W" ? -longitude : longitude
        )

        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

        return Metadata(coordinate: coordinate, capturedAt: capturedDate(from: properties))
    }

    private static func capturedDate(from properties: [CFString: Any]) -> Date? {
        guard
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.date(from: raw)
    }

    /// EXIF が落ちていた場合の代替。写真ライブラリへの許可が要る。
    private static func readFromPhotoLibrary(localIdentifier: String) -> Metadata? {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return nil }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard
            let asset = assets.firstObject,
            let location = asset.location
        else {
            return nil
        }

        return Metadata(coordinate: location.coordinate, capturedAt: asset.creationDate)
    }
}
