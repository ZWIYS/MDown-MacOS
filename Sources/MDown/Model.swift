import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WebKit

let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mdx"]

struct FileNode: Identifiable, Hashable {
    let id: String          // полный путь
    let name: String
    let isDir: Bool
    var children: [FileNode]?
}

/// Одна корневая папка в боковой панели.
struct Root: Identifiable, Hashable {
    enum Kind { case main, extra, temp }
    let url: URL
    var tree: [FileNode]
    let kind: Kind
    var id: String { url.path }
}

enum ReadMode: String, CaseIterable { case rendered, source }

enum AppTheme: String, CaseIterable {
    case system, light, dark
    var scheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
    var title: String {
        switch self { case .system: return "Как в системе"; case .light: return "Светлая"; case .dark: return "Тёмная" }
    }
    var icon: String {
        switch self { case .system: return "circle.lefthalf.filled"; case .light: return "sun.max"; case .dark: return "moon" }
    }
}

/// Пастельный оттенок фона (те же тона, что у выделения текста).
enum Tint: String, CaseIterable {
    case none, yellow, green, blue, pink, purple, orange

    var title: String {
        switch self {
        case .none: return "Без цвета"; case .yellow: return "Лимон"; case .green: return "Мята"
        case .blue: return "Небо"; case .pink: return "Розовый"; case .purple: return "Сирень"; case .orange: return "Персик"
        }
    }
    var lightHex: String {
        switch self {
        case .none: return "#ffffff"; case .yellow: return "#fff8d6"; case .green: return "#eaf7e5"
        case .blue: return "#e6f2ff"; case .pink: return "#ffeaf1"; case .purple: return "#f0eaff"; case .orange: return "#fff0e1"
        }
    }
    var darkHex: String {
        switch self {
        case .none: return "#1e1e1e"; case .yellow: return "#2c2a19"; case .green: return "#1c2a1f"
        case .blue: return "#1a2633"; case .pink: return "#2f1d25"; case .purple: return "#251f33"; case .orange: return "#302519"
        }
    }
    var swatchHex: String {
        switch self {
        case .none: return "#e5e5ea"; case .yellow: return "#fff1a8"; case .green: return "#cdeec8"
        case .blue: return "#c4e3ff"; case .pink: return "#ffd3e2"; case .purple: return "#e2d6ff"; case .orange: return "#ffdcb9"
        }
    }
    var swatch: Color { Color(nsColor: Tint.color(swatchHex)) }

    /// Цвет фона для нативных вью: сам переключается между светлой и тёмной темой.
    var nsColor: NSColor {
        let l = Tint.color(lightHex), d = Tint.color(darkHex)
        return NSColor(name: nil) { ap in ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l }
    }

    /// Фон боковой панели: тот же оттенок, чуть темнее (светлая тема) или светлее (тёмная).
    var sidebarColor: NSColor {
        let l = Tint.color(lightHex).blended(withFraction: 0.05, of: .black) ?? Tint.color(lightHex)
        let d = Tint.color(darkHex).blended(withFraction: 0.06, of: .white) ?? Tint.color(darkHex)
        return NSColor(name: nil) { ap in ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l }
    }

    static func color(_ hex: String) -> NSColor {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0xffffff
        return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                       blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}

/// Цветная метка раздела или заметки (точка, как теги в Finder).
enum LabelTag: String, CaseIterable {
    case y, g, b, p, v, o
    var title: String {
        switch self { case .y: return "Жёлтый"; case .g: return "Зелёный"; case .b: return "Голубой"
        case .p: return "Розовый"; case .v: return "Сиреневый"; case .o: return "Персиковый" }
    }
    var emoji: String {
        switch self { case .y: return "🟡"; case .g: return "🟢"; case .b: return "🔵"; case .p: return "🩷"; case .v: return "🟣"; case .o: return "🟠" }
    }
    /// Чуть насыщеннее фоновых пастелей, чтобы точка была видна на любом фоне.
    var color: Color {
        let hex: String
        switch self { case .y: hex = "#f2c744"; case .g: hex = "#63c26b"; case .b: hex = "#58a6f2"
        case .p: hex = "#f2729f"; case .v: hex = "#a182ee"; case .o: hex = "#f59e56" }
        return Color(nsColor: Tint.color(hex))
    }
}

@MainActor
final class ReaderModel: ObservableObject {
    static var defaultMain: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MDown", isDirectory: true).standardizedFileURL
    }

    @Published var fileURL: URL?
    @Published var text = ""
    @Published var roots: [Root] = []
    @Published var selection: String?
    @Published var expanded: Set<String> = []
    @Published var renaming: String?          // путь элемента, который сейчас переименовывается на месте
    @Published var editing = false
    @Published var split = false { didSet { if split { editing = true } } }

    @Published var mainURL: URL
    @Published var extraFolders: [URL] { didSet { UserDefaults.standard.set(extraFolders.map(\.path), forKey: "extraFolders") } }
    @Published var labels: [String: String] { didSet { UserDefaults.standard.set(labels, forKey: "labels") } }   // путь -> цвет метки
    @Published var tempFolder: URL?           // папка внешнего файла, открытого через «Открыть…»

    @Published var mode: ReadMode { didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") } }
    @Published var theme: AppTheme { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") } }
    @Published var tint: Tint { didSet { UserDefaults.standard.set(tint.rawValue, forKey: "tint") } }
    @Published var zoom: Double { didSet { UserDefaults.standard.set(zoom, forKey: "zoom") } }

    // Поиск (⌘F)
    @Published var searchOpen = false
    @Published var searchText = ""
    @Published var searchFocusTick = 0
    weak var activeWebView: WKWebView?
    weak var activeTextView: NSTextView?

    private var dirty = false
    private var saveTask: Task<Void, Never>?

    init() {
        let d = UserDefaults.standard
        mode = ReadMode(rawValue: d.string(forKey: "mode") ?? "") ?? .rendered
        theme = AppTheme(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        tint = Tint(rawValue: d.string(forKey: "tint") ?? "") ?? .none
        let z = d.double(forKey: "zoom")
        zoom = z > 0 ? z : 1.0
        mainURL = d.string(forKey: "mainFolder").map { URL(fileURLWithPath: $0).standardizedFileURL } ?? Self.defaultMain
        labels = (d.dictionary(forKey: "labels") as? [String: String]) ?? [:]
        extraFolders = (d.stringArray(forKey: "extraFolders") ?? []).map { URL(fileURLWithPath: $0).standardizedFileURL }

        Self.ensureLibrary(mainURL)
        rebuildRoots()
        if let arg = CommandLine.arguments.dropFirst().first(where: { FileManager.default.fileExists(atPath: $0) }) {
            open(URL(fileURLWithPath: arg))
        } else if let last = d.string(forKey: "lastFile"), FileManager.default.fileExists(atPath: last) {
            open(URL(fileURLWithPath: last))
        }
    }

    /// Создаёт основную папку при первом запуске и кладёт туда приветственную заметку.
    static func ensureLibrary(_ url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else { return }
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        let welcome = """
        # Добро пожаловать в MDown

        Все заметки живут в основной папке (по умолчанию `Documents/MDown`). Подпапки — это **разделы**.

        - **Новая заметка** — ⌘N, **новый раздел** — ⇧⌘N. Новый элемент сразу появляется в списке, и его можно назвать.
        - Правый клик (два пальца) по списку — то же меню, а ещё «Переименовать» и «В Корзину».
        - Кнопка с карандашом (⌘E) включает правку. В «Красиво» кликните по абзацу, в «Исходнике» правится весь текст. Кнопка со сплитом показывает исходник и результат рядом.
        - Выделите текст и кликните двумя пальцами — меню форматирования: заголовок, жирный, курсив, цвет.
        - Настройки (⌘,) — основная папка, дополнительные папки и цвет темы.
        """
        try? welcome.write(to: url.appendingPathComponent("Добро пожаловать.md"), atomically: true, encoding: .utf8)
    }

    static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    // MARK: Корни

    func rebuildRoots() {
        var r = [Root(url: mainURL, tree: Self.buildTree(mainURL, keepEmpty: true), kind: .main)]
        for u in extraFolders where u.path != mainURL.path {
            r.append(Root(url: u, tree: Self.buildTree(u, keepEmpty: true), kind: .extra))
        }
        if let t = tempFolder, !r.contains(where: { $0.url.path == t.path }) {
            r.append(Root(url: t, tree: Self.buildTree(t, keepEmpty: false), kind: .temp))
        }
        roots = r
    }

    func root(containing path: String) -> Root? {
        roots.filter { path == $0.url.path || path.hasPrefix($0.url.path + "/") }
            .max { $0.url.path.count < $1.url.path.count }
    }

    private func expandAncestors(of path: String) {
        guard let root = root(containing: path) else { return }
        var p = URL(fileURLWithPath: path).deletingLastPathComponent()
        while p.path.count > root.url.path.count {
            expanded.insert(p.path)
            p = p.deletingLastPathComponent()
        }
    }

    // MARK: Открытие

    func open(_ input: URL) {
        let url = input.standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        if Self.isDirectory(url.path) {
            if root(containing: url.path) == nil { tempFolder = url; rebuildRoots() }
            selection = url.path
            expandAncestors(of: url.path)
            expanded.insert(url.path)
            if let r = roots.first(where: { $0.url.path == url.path }), let first = firstDocument(in: r.tree) {
                open(URL(fileURLWithPath: first))
            }
            return
        }
        saveNow()
        guard url != fileURL, let data = try? Data(contentsOf: url) else { return }
        text = String(decoding: data, as: UTF8.self)
        fileURL = url
        if root(containing: url.path) == nil { tempFolder = url.deletingLastPathComponent(); rebuildRoots() }
        selection = url.path
        expandAncestors(of: url.path)
        UserDefaults.standard.set(url.path, forKey: "lastFile")
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Выберите markdown-файл или папку"
        panel.allowedContentTypes = markdownExtensions.compactMap { UTType(filenameExtension: $0) } + [.plainText]
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    /// Перечитать дерево и файл (вызывается при возврате в приложение).
    func refresh() {
        rebuildRoots()
        if let url = fileURL, !dirty, let data = try? Data(contentsOf: url) {
            let new = String(decoding: data, as: UTF8.self)
            if new != text { text = new }
        }
    }

    // MARK: Папки (настройки)

    private func pickFolder(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = message
        return panel.runModal() == .OK ? panel.url?.standardizedFileURL : nil
    }

    func chooseMainFolder() {
        guard let url = pickFolder(message: "Выберите основную папку для заметок") else { return }
        setMain(url)
    }

    func resetMainFolder() { setMain(Self.defaultMain) }

    private func setMain(_ url: URL) {
        saveNow()
        mainURL = url
        UserDefaults.standard.set(url.path, forKey: "mainFolder")
        Self.ensureLibrary(url)
        extraFolders.removeAll { $0.path == url.path }
        rebuildRoots()
    }

    func addExtraFolder() {
        guard let url = pickFolder(message: "Добавьте папку с заметками") else { return }
        guard url.path != mainURL.path, !extraFolders.contains(where: { $0.path == url.path }) else { return }
        extraFolders.append(url)
        rebuildRoots()
    }

    func removeExtraFolder(_ url: URL) {
        extraFolders.removeAll { $0.path == url.path }
        rebuildRoots()
    }

    func pinTempFolder() {
        guard let t = tempFolder else { return }
        tempFolder = nil
        if !extraFolders.contains(where: { $0.path == t.path }) && t.path != mainURL.path { extraFolders.append(t) }
        rebuildRoots()
    }

    func closeTempFolder() {
        tempFolder = nil
        rebuildRoots()
    }

    // MARK: Заметки и разделы

    /// Куда создавать новое: выбранный раздел, иначе папка выбранной/открытой заметки, иначе основная папка.
    var targetFolder: URL {
        if let sel = selection {
            if Self.isDirectory(sel) { return URL(fileURLWithPath: sel) }
            if root(containing: sel) != nil { return URL(fileURLWithPath: sel).deletingLastPathComponent() }
        }
        if let f = fileURL, root(containing: f.path) != nil { return f.deletingLastPathComponent() }
        return mainURL
    }

    /// Создаёт заметку сразу и включает переименование прямо в списке.
    func createNote(in dir: URL? = nil) {
        saveNow()
        let folder = dir ?? targetFolder
        let url = uniqueURL(in: folder, name: "Новая заметка", ext: "md")
        do { try "".write(to: url, atomically: true, encoding: .utf8) } catch { NSSound.beep(); return }
        expanded.insert(folder.path)
        expandAncestors(of: url.path)
        rebuildRoots()
        open(url)
        editing = true
        renaming = url.path
    }

    func createSection(in dir: URL? = nil) {
        let folder = dir ?? targetFolder
        let url = uniqueURL(in: folder, name: "Новый раздел", ext: nil)
        do { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false) } catch { NSSound.beep(); return }
        expanded.insert(folder.path)
        expandAncestors(of: url.path)
        rebuildRoots()
        selection = url.path
        renaming = url.path
    }

    func setLabel(_ path: String, _ tag: LabelTag?) { labels[path] = tag?.rawValue }

    /// Своя метка элемента или метка ближайшего раздела выше: положили заметку в «синий» раздел — она тоже синяя.
    func labelTag(for path: String) -> LabelTag? {
        guard let root = root(containing: path) else { return nil }
        var p = path
        while true {
            if let k = labels[p], let t = LabelTag(rawValue: k) { return t }
            guard p.count > root.url.path.count else { return nil }
            p = (p as NSString).deletingLastPathComponent
        }
    }

    func beginRename(_ path: String) { renaming = path }
    func cancelRename() { renaming = nil }

    func commitRename(_ path: String, to raw: String) {
        renaming = nil
        saveNow()
        let old = URL(fileURLWithPath: path)
        let isDir = Self.isDirectory(path)
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let ext = old.pathExtension.isEmpty ? "md" : old.pathExtension
        if !isDir, name.lowercased().hasSuffix("." + ext.lowercased()) { name = String(name.dropLast(ext.count + 1)) }
        guard !name.isEmpty else { return }
        var new = old.deletingLastPathComponent().appendingPathComponent(name)
        if !isDir { new = new.appendingPathExtension(ext) }
        guard new.path != old.path else { return }
        guard !FileManager.default.fileExists(atPath: new.path) else { NSSound.beep(); return }
        do { try FileManager.default.moveItem(at: old, to: new) } catch { NSSound.beep(); return }
        moveHighlights(from: old.path, to: new.path)

        func remap(_ p: String) -> String? {
            p == old.path || p.hasPrefix(old.path + "/") ? new.path + String(p.dropFirst(old.path.count)) : nil
        }
        if let f = fileURL, let np = remap(f.path) {
            fileURL = URL(fileURLWithPath: np)
            UserDefaults.standard.set(np, forKey: "lastFile")
        }
        if let s = selection, let np = remap(s) { selection = np }
        labels = Dictionary(labels.map { (remap($0.key) ?? $0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
        expanded = Set(expanded.map { remap($0) ?? $0 })
        rebuildRoots()
    }

    func trash(_ path: String) {
        saveNow()
        let url = URL(fileURLWithPath: path)
        do { try FileManager.default.trashItem(at: url, resultingItemURL: nil) } catch { NSSound.beep(); return }
        if let f = fileURL, f.path == path || f.path.hasPrefix(path + "/") {
            fileURL = nil; text = ""; selection = nil; dirty = false
            UserDefaults.standard.removeObject(forKey: "lastFile")
        }
        rebuildRoots()
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func uniqueURL(in folder: URL, name: String, ext: String?) -> URL {
        func make(_ n: String) -> URL {
            let u = folder.appendingPathComponent(n)
            return ext.map { u.appendingPathExtension($0) } ?? u
        }
        var candidate = make(name), i = 2
        while FileManager.default.fileExists(atPath: candidate.path) { candidate = make("\(name) \(i)"); i += 1 }
        return candidate
    }

    // MARK: Редактирование и сохранение

    func textEdited(_ new: String) {
        guard new != text else { return }
        text = new
        dirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if !Task.isCancelled { self?.saveNow() }
        }
    }

    func saveNow() {
        saveTask?.cancel()
        guard dirty, let url = fileURL else { return }
        do { try text.write(to: url, atomically: true, encoding: .utf8); dirty = false }
        catch { NSSound.beep() }
    }

    // MARK: Выделения (хранятся отдельно, сам .md не меняется)

    private static let highlightsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("MDown", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("highlights.json")
        let old = support.appendingPathComponent("MDReader/highlights.json")   // старое имя приложения
        if !FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: old.path) {
            try? FileManager.default.copyItem(at: old, to: url)
        }
        return url
    }()
    private lazy var highlightStore: [String: String] = {
        (try? Data(contentsOf: Self.highlightsURL))
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }()

    func highlightsJSON(for path: String) -> String { highlightStore[path] ?? "[]" }

    func setHighlights(_ json: String, for path: String) {
        highlightStore[path] = json == "[]" ? nil : json
        persistHighlights()
    }

    private func moveHighlights(from old: String, to new: String) {
        var changed = false
        for (k, v) in highlightStore where k == old || k.hasPrefix(old + "/") {
            highlightStore[new + String(k.dropFirst(old.count))] = v
            highlightStore[k] = nil
            changed = true
        }
        if changed { persistHighlights() }
    }

    private func persistHighlights() {
        if let d = try? JSONEncoder().encode(highlightStore) { try? d.write(to: Self.highlightsURL, options: .atomic) }
    }

    // MARK: Поиск

    func openSearch() {
        searchOpen = true
        searchFocusTick += 1
    }

    func closeSearch() {
        searchOpen = false
        activeWebView?.evaluateJavaScript("getSelection().removeAllRanges()")
    }

    /// Ищем в исходнике, если он на экране (в сплите тоже), иначе в красивом виде.
    func find(backwards: Bool = false) {
        guard !searchText.isEmpty, fileURL != nil else { return }
        if split || mode == .source, let tv = activeTextView {
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            let needle = searchText
            var opts: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            var range = NSRange(location: NSNotFound, length: 0)
            if backwards {
                opts.insert(.backwards)
                range = ns.range(of: needle, options: opts, range: NSRange(location: 0, length: sel.location))
                if range.location == NSNotFound { range = ns.range(of: needle, options: opts) }
            } else {
                let isCurrent = sel.length > 0 && ns.substring(with: sel).compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                let start = isCurrent ? sel.location + sel.length : sel.location
                range = ns.range(of: needle, options: opts, range: NSRange(location: start, length: ns.length - start))
                if range.location == NSNotFound { range = ns.range(of: needle, options: opts) }
            }
            if range.location != NSNotFound {
                tv.setSelectedRange(range)
                tv.scrollRangeToVisible(range)
                tv.showFindIndicator(for: range)
            } else { NSSound.beep() }
        } else if let wv = activeWebView {
            let cfg = WKFindConfiguration()
            cfg.backwards = backwards
            cfg.wraps = true
            cfg.caseSensitive = false
            wv.find(searchText, configuration: cfg) { result in
                if !result.matchFound { NSSound.beep() }
            }
        }
    }

    // MARK: Масштаб

    func zoomIn() { zoom = min(3.0, (zoom * 1.1 * 100).rounded() / 100) }
    func zoomOut() { zoom = max(0.5, (zoom / 1.1 * 100).rounded() / 100) }
    func zoomReset() { zoom = 1.0 }
    func zoomBy(magnification m: CGFloat) { zoom = min(3.0, max(0.5, zoom * (1 + Double(m)))) }

    // MARK: Дерево

    private func firstDocument(in nodes: [FileNode]) -> String? {
        if let readme = nodes.first(where: { !$0.isDir && $0.name.lowercased().hasPrefix("readme") }) { return readme.id }
        if let f = nodes.first(where: { !$0.isDir }) { return f.id }
        for n in nodes { if let c = n.children, let f = firstDocument(in: c) { return f } }
        return nil
    }

    private static let skipDirs: Set<String> = ["node_modules", ".git", "build", ".build", "Pods", "DerivedData", "Library"]

    static func buildTree(_ root: URL, keepEmpty: Bool) -> [FileNode] {
        var budget = 8000
        return build(root, depth: 0, budget: &budget, keepEmpty: keepEmpty)
    }

    private static func build(_ dir: URL, depth: Int, budget: inout Int, keepEmpty: Bool) -> [FileNode] {
        guard budget > 0,
              let items = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return [] }
        var dirs: [FileNode] = [], files: [FileNode] = []
        for u in items {
            budget -= 1
            let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                guard depth < 8, !skipDirs.contains(u.lastPathComponent) else { continue }
                let ch = build(u, depth: depth + 1, budget: &budget, keepEmpty: keepEmpty)
                if !ch.isEmpty || keepEmpty {
                    dirs.append(FileNode(id: u.path, name: u.lastPathComponent, isDir: true, children: ch.isEmpty ? nil : ch))
                }
            } else if markdownExtensions.contains(u.pathExtension.lowercased()) {
                files.append(FileNode(id: u.path, name: u.lastPathComponent, isDir: false, children: nil))
            }
        }
        let cmp: (FileNode, FileNode) -> Bool = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return dirs.sorted(by: cmp) + files.sorted(by: cmp)
    }
}
