import Foundation

enum Destination: String, Codable, CaseIterable {
    case collections, mercury, videos
    var path: String {
        let base = "Library/Application Support/PRBPosterExtensionDataStore/61/Extensions/"
        switch self {
        case .collections: return base + "com.apple.WallpaperKit.CollectionsPoster/descriptors"
        case .mercury: return base + "com.apple.MercuryPoster/descriptors"
        case .videos: return base + "com.apple.PhotosUIPrivate.PhotosPosterProvider/descriptors"
        }
    }
}
struct Wallpaper: Identifiable, Codable {
    var id: UUID
    var name: String
    var destination: Destination
    var descriptors: [String]
    var queued = true
}
struct Installed: Codable {
    var container: String
    var destination: Destination
    var name: String
}
enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
