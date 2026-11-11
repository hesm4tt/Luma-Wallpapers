import Foundation
import Darwin

struct PosterService {
    let library: URL
    let journal: URL
    var log: (String) -> Void = { _ in }
    private let fm = FileManager.default
    private var group: String? {
        guard let task = SecTaskCreateFromSelf(nil), let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String] else { return nil }
        return value.first { fm.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
    }
    private func access(_ path: String) throws -> Int64 {
        guard let group else { log("ERROR: No provisioned App Group is available."); throw AppError.message("No usable App Group was found. Re-sign with an App Group-enabled profile.") }
        let result = worse_query(path, group, false, false)
        guard result >= 0 else { throw AppError.message("Could not access PosterBoard (worse_query error \(result)). Check the App Group and iOS compatibility.") }
        return result
    }
    func findContainer() throws -> String {
        log("Checking the signed App Group entitlement…")
        guard group != nil else { throw AppError.message("No usable App Group was found. Re-sign with an App Group-enabled profile.") }
        log("App Group is available.")
        let baseline = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: baseline)
        defer { try? fm.removeItem(at: baseline) }
        var info = stat()
        guard stat(baseline.path, &info) == 0 else { throw AppError.message("Could not start container detection.") }
        let root = "/var/mobile/Containers/Data/Application"
        log("Scanning application container paths; this may take a while…")
        guard let paths = pathleak_with_progress(root, info.st_ino, { current, total in
            log("Container scan: \(current) of \(total) inode numbers checked.")
        }) else { throw AppError.message("Could not scan application containers.") }
        log("Scan found \(paths.count) candidate containers. Checking identifiers…")
        var accessFailures = 0
        var identifierFailures = 0
        for path in paths {
            guard let handle = try? access(path) else { accessFailures += 1; continue }
            var buf = [CChar](repeating: 0, count: 1024)
            let length = getxattr(path, "com.apple.containermanager.identifier", &buf, buf.count - 1, 0, 0)
            worse_query_release(handle)
            if length > 0, String(cString: buf) == "com.apple.PosterBoard" { log("PosterBoard container found."); return path }
            if length <= 0 { identifierFailures += 1 }
        }
        log("Checked \(paths.count) candidates: \(accessFailures) access failures, \(identifierFailures) identifier read failures.")
        if paths.isEmpty { throw AppError.message("No application container paths were returned by the scan.") }
        throw AppError.message("PosterBoard was not found among \(paths.count) candidates. See the activity log for access and identifier failures.")
    }
    func records() throws -> [Installed] {
        guard fm.fileExists(atPath: journal.path) else { return [] }
        return try JSONDecoder().decode([Installed].self, from: Data(contentsOf: journal))
    }
    private func save(_ records: [Installed]) throws { try JSONEncoder().encode(records).write(to: journal, options: .atomic) }
    func apply(_ wallpapers: [Wallpaper]) throws -> Int {
        guard !wallpapers.isEmpty else { throw AppError.message("Select at least one wallpaper.") }
        guard wallpapers.reduce(0, { $0 + $1.descriptors.count }) <= 15 else { throw AppError.message("Select no more than 15 wallpapers at a time.") }
        log("Preparing \(wallpapers.count) selected pack(s), \(wallpapers.reduce(0, { $0 + $1.descriptors.count })) descriptor(s).")
        let container = try findContainer()
        var installed = try records()
        var written = 0
        for wallpaper in wallpapers {
            log("Opening \(wallpaper.name) (\(wallpaper.destination.rawValue)).")
            let target = URL(fileURLWithPath: container).appendingPathComponent(wallpaper.destination.path)
            log("Requesting worse_query access to \(wallpaper.destination.rawValue) descriptors…")
            let handle = try access(target.path)
            log("Access granted. Copying \(wallpaper.descriptors.count) descriptor(s).")
            defer { worse_query_release(handle) }
            for name in wallpaper.descriptors {
                let source = library.appendingPathComponent(wallpaper.id.uuidString).appendingPathComponent(name)
                let outputName = wallpaper.destination == .mercury ? name : UUID().uuidString
                let output = target.appendingPathComponent(outputName)
                guard !fm.fileExists(atPath: output.path) else { throw AppError.message("A wallpaper with this identifier already exists. \(written) descriptor(s) were added before the conflict.") }
                let record = Installed(container: container, destination: wallpaper.destination, name: outputName)
                do {
                    try fm.copyItem(at: source, to: output)
                    installed.append(record)
                    do { try save(installed) } catch { try? fm.removeItem(at: output); throw error }
                    written += 1
                    log("Copied and recorded descriptor \(written).")
                } catch {
                    try? fm.removeItem(at: output)
                    throw AppError.message("Apply stopped after \(written) descriptor(s): \(error.localizedDescription). Use Reset to remove files recorded by Luma.")
                }
            }
        }
        log("Finished: \(written) descriptor(s) added.")
        return written
    }
    func reset() throws -> Int {
        var installed = try records()
        log("Reset: \(installed.count) recorded descriptor(s).")
        guard !installed.isEmpty else { log("Nothing to remove."); return 0 }
        let container = try findContainer()
        guard installed.allSatisfy({ $0.container == container }) else { throw AppError.message("PosterBoard's container changed. Luma will not delete files using an old path.") }
        var removed = 0
        while let record = installed.first {
            guard !record.name.isEmpty, record.name != ".", record.name != "..", !record.name.contains("/") else { throw AppError.message("Invalid reset record. No further files were removed.") }
            let target = URL(fileURLWithPath: container).appendingPathComponent(record.destination.path)
            let handle = try access(target.path)
            do {
                let file = target.appendingPathComponent(record.name)
                if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file); removed += 1; log("Removed recorded descriptor \(removed).") }
                worse_query_release(handle)
            } catch { worse_query_release(handle); throw error }
            installed.removeFirst()
            try save(installed)
        }
        log("Reset finished: \(removed) descriptor(s) removed.")
        return removed
    }
}
