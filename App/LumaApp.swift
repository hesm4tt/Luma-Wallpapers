import SwiftUI
import UniformTypeIdentifiers
import UIKit

@main struct LumaApp: App {
    var body: some Scene { WindowGroup { HomeView() } }
}

@MainActor final class Library: ObservableObject {
    @Published var items: [Wallpaper] = []
    @Published var busy = false
    @Published var status = ""
    @Published var message: String?
    @Published var activity: [String] = []
    @Published var showActivity = false
    func addLog(_ line: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        activity.append("[\(stamp)] \(line)")
    }
    let root: URL
    var index: URL { root.appendingPathComponent("library.json") }
    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Luma", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: index.path) { items = try JSONDecoder().decode([Wallpaper].self, from: Data(contentsOf: index)) }
        } catch { message = "Could not load the library: \(error.localizedDescription)" }
    }
    func save() throws { try JSONEncoder().encode(items).write(to: index, options: .atomic) }
    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].queued.toggle()
        do { try save() } catch { items[i].queued.toggle(); message = error.localizedDescription }
    }
    func remove(_ item: Wallpaper) {
        let old = items
        items.removeAll { $0.id == item.id }
        do { try save(); try FileManager.default.removeItem(at: root.appendingPathComponent(item.id.uuidString)) }
        catch { items = old; try? save(); message = "Could not remove wallpaper: \(error.localizedDescription)" }
    }
    func importFile(_ url: URL) {
        busy = true; status = "Importing wallpaper…"
        let root = root
        Task.detached {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let item = try Importer(root: root).run(url)
                await MainActor.run {
                    self.items.append(item)
                    do { try self.save(); self.message = "Imported \(item.name). Select it and tap Apply." }
                    catch { self.items.removeAll { $0.id == item.id }; try? FileManager.default.removeItem(at: root.appendingPathComponent(item.id.uuidString)); self.message = "Could not save the library: \(error.localizedDescription)" }
                    self.busy = false
                }
            } catch { await MainActor.run { self.message = "Import failed: \(error.localizedDescription)"; self.busy = false } }
        }
    }
    func perform(reset: Bool) {
        busy = true; status = reset ? "Removing Luma wallpapers…" : "Finding PosterBoard and applying…"
        activity = []; showActivity = true
        addLog(reset ? "Starting reset." : "Starting apply.")
        let selected = items.filter(\.queued), root = root
        Task.detached {
            do {
                let service = PosterService(library: root, journal: root.appendingPathComponent("installed.json"), log: { line in
                    DispatchQueue.main.async { self.addLog(line) }
                })
                let count = try reset ? service.reset() : service.apply(selected)
                await MainActor.run { self.busy = false; self.addLog("Operation completed."); self.message = reset ? "Removed \(count) recorded descriptor(s). Restart your iPhone to refresh the wallpaper picker." : "Added \(count) descriptor(s). Restart your iPhone, then open the Lock Screen wallpaper picker." }
            } catch { await MainActor.run { self.busy = false; self.addLog("ERROR: \(error.localizedDescription)"); self.message = "\(reset ? "Reset" : "Apply") failed: \(error.localizedDescription)" } }
        }
    }
}
struct HomeView: View {
    @StateObject private var library = Library()
    @State private var importer = false
    @State private var confirmReset = false
    @State private var deleteItem: Wallpaper?
    private let accent = Color(red: 0.12, green: 0.53, blue: 0.77)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MAKE IT YOURS").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(accent)
                        Text("Your wallpapers,\nyour way.").font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-1)
                        Text("Import a .tendies file, select it, and add it to your Lock Screen collection.").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(24).lumaGlass(cornerRadius: 26)
                    HStack { Text("Library").font(.title2.bold()); Spacer(); Text("\(library.items.count) packs").font(.subheadline).foregroundStyle(.secondary) }
                    if library.items.isEmpty {
                        VStack(spacing: 12) { Image(systemName: "square.stack.3d.up").font(.system(size: 36)).foregroundStyle(accent); Text("Your library is empty").font(.headline); Text("Add a .tendies file from Files to get started.").font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 35)
                    } else {
                        ForEach(library.items) { item in
                            HStack(spacing: 14) {
                                Image(systemName: item.destination == .videos ? "play.rectangle.fill" : "photo.fill").font(.title2).foregroundStyle(accent).frame(width: 52, height: 52).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.headline).lineLimit(1); Text("\(item.descriptors.count) descriptor\(item.descriptors.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Button { library.toggle(item.id) } label: { Image(systemName: item.queued ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(item.queued ? accent : .secondary) }.accessibilityLabel(item.queued ? "Remove \(item.name) from queue" : "Add \(item.name) to queue")
                            }.padding(14).lumaGlass(cornerRadius: 20)
                            .contextMenu { Button("Delete from library", role: .destructive) { deleteItem = item } }
                        }
                    }
                    Button { importer = true } label: { Label("Import .tendies", systemImage: "plus").frame(maxWidth: .infinity).padding(16) }.buttonStyle(.bordered).tint(accent).disabled(library.busy)
                    Button { library.perform(reset: false) } label: { Text("Apply selected (\(library.items.filter(\.queued).count))").fontWeight(.semibold).frame(maxWidth: .infinity).padding(12) }.buttonStyle(.borderedProminent).tint(accent).disabled(library.busy || !library.items.contains(where: \.queued))
                    Button { library.showActivity = true } label: { Label("View activity", systemImage: "terminal").font(.subheadline.weight(.medium)) }.disabled(library.activity.isEmpty)
                    Text("Back up your iPhone before applying. Only use wallpaper files you trust.").font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }.background(LinearGradient(colors: [Color(red: 0.86, green: 0.96, blue: 1), Color(uiColor: .systemGroupedBackground), Color(red: 0.81, green: 0.93, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()).navigationTitle("Luma").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("Reset Luma wallpapers", role: .destructive) { confirmReset = true }; NavigationLink("About & licenses") { AboutView() } } label: { Image(systemName: "ellipsis.circle") } } }
            .sheet(isPresented: $library.showActivity) { ActivityView(library: library) }
            .interactiveDismissDisabled(library.busy)
            .fileImporter(isPresented: $importer, allowedContentTypes: [.item]) { result in switch result { case .success(let url): library.importFile(url); case .failure(let error): library.message = error.localizedDescription } }
            .alert("Reset Luma wallpapers?", isPresented: $confirmReset) { Button("Remove recorded wallpapers", role: .destructive) { library.perform(reset: true) }; Button("Cancel", role: .cancel) {} } message: { Text("This removes only the PosterBoard descriptors recorded as installed by Luma. Your imported library remains. You may need to restart your iPhone.") }
            .alert("Delete from library?", isPresented: Binding(get: { deleteItem != nil }, set: { if !$0 { deleteItem = nil } })) { Button("Delete", role: .destructive) { if let item = deleteItem { library.remove(item) }; deleteItem = nil }; Button("Cancel", role: .cancel) { deleteItem = nil } } message: { Text("This removes the local import. It does not remove already applied wallpapers; use Reset for those.") }
            .alert("Luma", isPresented: Binding(get: { library.message != nil }, set: { if !$0 { library.message = nil } })) { Button("OK") { library.message = nil } } message: { Text(library.message ?? "") }
        }
    }
}
struct AboutView: View {
    var body: some View { List { Section("Luma") { Text("A focused .tendies wallpaper importer."); Text("An App Group-enabled signature is required. Compatibility depends on the device and iOS build.") }; Section("Credits") { Link("worse_query and pathleak by forcequit and contributors", destination: URL(string: "https://github.com/forcequitOS/worse_query")!); Link("ZIPFoundation", destination: URL(string: "https://github.com/weichsel/ZIPFoundation")!); Text("worse_query is licensed under GPL-3.0-or-later. License and source are distributed with this app.") } }.navigationTitle("About") }
}


struct LumaGlass: ViewModifier {
    var radius: CGFloat
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.4), lineWidth: 0.7))
        }
    }
}
extension View { func lumaGlass(cornerRadius: CGFloat) -> some View { modifier(LumaGlass(radius: cornerRadius)) } }

struct ActivityView: View {
    @ObservedObject var library: Library
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack { if library.busy { ProgressView().controlSize(.small) }; Text(library.busy ? library.status : "Last operation").font(.subheadline.weight(.semibold)); Spacer() }
                Text("Detailed progress stays on this device until you copy it.").font(.caption).foregroundStyle(.secondary)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(library.activity.enumerated()), id: \.offset) { index, line in
                                Text(line).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).id(index)
                            }
                        }.padding(16)
                    }.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .onChange(of: library.activity.count) { _ in if let last = library.activity.indices.last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } } }
                }
            }.padding().navigationTitle("Activity").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Copy") { UIPasteboard.general.string = library.activity.joined(separator: "\n") }.disabled(library.activity.isEmpty) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.disabled(library.busy) }
            }
            .interactiveDismissDisabled(library.busy)
        }
    }
}
