import Foundation
import ZIPFoundation

struct Importer {
    let root: URL
    func run(_ url: URL) throws -> Wallpaper {
        guard url.pathExtension.lowercased() == "tendies" else { throw AppError.message("Choose a .tendies file.") }
        let archive: Archive
        do { archive = try Archive(url: url, accessMode: .read) } catch { throw AppError.message("This file is not a readable ZIP archive.") }
        let entries = Array(archive)
        guard !entries.isEmpty, entries.count <= 10000 else { throw AppError.message("The archive is empty or contains too many files.") }
        var size: UInt64 = 0
        var seen = Set<String>()
        for entry in entries {
            let path = entry.path
            let components = path.split(separator: "/", omittingEmptySubsequences: true)
            guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0"), !components.isEmpty,
                  !components.contains(".."), !components.contains("."), entry.type != .symlink,
                  seen.insert(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).inserted else {
                throw AppError.message("The archive contains an unsafe or duplicate path.")
            }
            let (next, overflow) = size.addingReportingOverflow(entry.uncompressedSize)
            guard !overflow, next <= 1_000_000_000 else { throw AppError.message("The archive is too large to import.") }
            size = next
        }
        let fm = FileManager.default
        let temp = root.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }
        for entry in entries {
            let destination = temp.appendingPathComponent(entry.path).standardizedFileURL
            guard destination.path.hasPrefix(temp.standardizedFileURL.path + "/") else { throw AppError.message("Unsafe archive path.") }
            if entry.type == .directory { try fm.createDirectory(at: destination, withIntermediateDirectories: true) }
            else {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: destination)
            }
        }
        guard let enumerator = fm.enumerator(at: temp, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { throw AppError.message("Could not inspect the wallpaper.") }
        var candidates: [(URL, Destination)] = []
        for case let item as URL in enumerator {
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let name = item.lastPathComponent.lowercased()
            if name.contains("descriptor") {
                let path = item.path.lowercased()
                let type: Destination = path.contains("mercuryposter") ? .mercury : (path.contains("photosposterprovider") || name.contains("video-descriptor") || fm.fileExists(atPath: item.appendingPathComponent("VideoCAML").path) ? .videos : .collections)
                candidates.append((item, type))
                enumerator.skipDescendants()
            }
        }
        guard candidates.count == 1, let candidate = candidates.first else { throw AppError.message("Expected one recognizable descriptor folder in the archive.") }
        let descriptors = try fm.contentsOfDirectory(at: candidate.0, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        guard !descriptors.isEmpty, descriptors.count <= 15, descriptors.allSatisfy({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }) else { throw AppError.message("No valid descriptor folders found (maximum 15 per file).") }
        let id = UUID()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            var names: [String] = []
            for descriptor in descriptors {
                let name = candidate.1 == .mercury ? descriptor.lastPathComponent : UUID().uuidString
                let dest = folder.appendingPathComponent(name)
                try fm.moveItem(at: descriptor, to: dest)
                if candidate.1 != .mercury { try randomize(dest) }
                names.append(name)
            }
            return Wallpaper(id: id, name: url.deletingPathExtension().lastPathComponent, destination: candidate.1, descriptors: names)
        } catch { try? fm.removeItem(at: folder); throw error }
    }
    private func randomize(_ dir: URL) throws {
        let id = Int.random(in: 10000...99999)
        guard let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return }
        for case let file as URL in en {
            if file.lastPathComponent == "com.apple.posterkit.provider.descriptor.identifier" { try String(id).write(to: file, atomically: true, encoding: .utf8) }
            let key: String? = file.lastPathComponent == "Wallpaper.plist" ? "identifier" : (file.lastPathComponent == "com.apple.posterkit.provider.contents.userInfo" ? "wallpaperRepresentingIdentifier" : nil)
            if let key {
                let data = try Data(contentsOf: file)
                guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw AppError.message("A wallpaper metadata file is invalid.") }
                plist[key] = id
                try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0).write(to: file, options: .atomic)
            }
        }
    }
}
