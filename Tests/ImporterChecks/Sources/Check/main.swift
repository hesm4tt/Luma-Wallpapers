import Foundation
import ZIPFoundation
let fm = FileManager.default
let dir = fm.temporaryDirectory.appendingPathComponent("luma-tests-\(UUID())")
try fm.createDirectory(at: dir, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: dir) }
let root = dir.appendingPathComponent("library")
try fm.createDirectory(at: root, withIntermediateDirectories: true)
func archive(_ name: String, entries: [String]) throws -> URL {
    let file = dir.appendingPathComponent(name + ".tendies")
    let archive = try Archive(url: file, accessMode: .create)
    for path in entries { let bytes = Data("hello".utf8); try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(bytes.count), provider: { position, size in bytes.subdata(in: Int(position)..<min(Int(position) + size, bytes.count)) }) }
    return file
}
func fails(_ label: String, _ block: () throws -> Void) {
    do { try block(); fatalError("\(label) unexpectedly succeeded") } catch { print("PASS \(label)") }
}
let valid = try archive("valid", entries: ["descriptors/one/asset.bin"])
let item = try Importer(root: root).run(valid)
assert(item.descriptors.count == 1 && item.queued)
assert(fm.fileExists(atPath: root.appendingPathComponent(item.id.uuidString).appendingPathComponent(item.descriptors[0]).appendingPathComponent("asset.bin").path))
print("PASS valid import")
let empty = try archive("empty", entries: [])
fails("empty") { _ = try Importer(root: root).run(empty) }
let traversal = try archive("traversal", entries: ["../escape"])
fails("unsafe traversal") { _ = try Importer(root: root).run(traversal) }
let invalid = dir.appendingPathComponent("invalid.tendies"); try Data("not a zip".utf8).write(to: invalid)
fails("malformed") { _ = try Importer(root: root).run(invalid) }
let missing = try archive("no-descriptors", entries: ["other/file"])
fails("missing descriptors") { _ = try Importer(root: root).run(missing) }
let corrupt = dir.appendingPathComponent("interrupted.tendies"); let data = try Data(contentsOf: valid); try data.prefix(data.count / 2).write(to: corrupt)
fails("interrupted archive") { _ = try Importer(root: root).run(corrupt) }
let leftovers = try fm.contentsOfDirectory(atPath: root.path)
assert(leftovers.filter { $0.hasPrefix("staging-") }.isEmpty)
print("PASS staging cleanup")
