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
        switch self { case .system: return tr("Follow System"); case .light: return tr("Light"); case .dark: return tr("Dark") }
    }
    var icon: String {
        switch self { case .system: return "circle.lefthalf.filled"; case .light: return "sun.max"; case .dark: return "moon" }
    }
}

/// Единая пастельная палитра в цветах macOS (плюс розовый): фон темы, выделение текста, метки.
enum Pastel: String, CaseIterable {
    case r, o, y, g, b, v, p, x   // красный, оранжевый, жёлтый, зелёный, синий, фиолетовый, розовый, серый

    var title: String {
        switch self {
        case .r: return tr("Red"); case .o: return tr("Orange"); case .y: return tr("Yellow"); case .g: return tr("Green")
        case .b: return tr("Blue"); case .v: return tr("Purple"); case .p: return tr("Pink"); case .x: return tr("Gray")
        }
    }
    /// Маркер в светлой теме
    var hlLight: String {
        switch self {
        case .r: return "#ffc9c4"; case .o: return "#ffdcb9"; case .y: return "#fff1a8"; case .g: return "#cdeec8"
        case .b: return "#c4e3ff"; case .v: return "#e2d6ff"; case .p: return "#ffd3e2"; case .x: return "#dcdce1"
        }
    }
    /// Маркер в тёмной теме (CSS)
    var hlDark: String {
        switch self {
        case .r: return "rgba(255,69,58,.34)"; case .o: return "rgba(255,159,10,.34)"; case .y: return "rgba(255,214,10,.30)"
        case .g: return "rgba(52,199,89,.30)"; case .b: return "rgba(10,132,255,.38)"; case .v: return "rgba(175,130,255,.40)"
        case .p: return "rgba(255,55,95,.32)"; case .x: return "rgba(152,152,157,.38)"
        }
    }
    var tintLight: String {
        switch self {
        case .r: return "#ffecea"; case .o: return "#fff0e1"; case .y: return "#fff8d6"; case .g: return "#eaf7e5"
        case .b: return "#e6f2ff"; case .v: return "#f0eaff"; case .p: return "#ffeaf1"; case .x: return "#efeff2"
        }
    }
    var tintDark: String {
        switch self {
        case .r: return "#33201f"; case .o: return "#302519"; case .y: return "#2c2a19"; case .g: return "#1c2a1f"
        case .b: return "#1a2633"; case .v: return "#251f33"; case .p: return "#2f1d25"; case .x: return "#29292c"
        }
    }
    /// Цвет точки-метки (как теги в Finder, но мягче)
    var dotHex: String {
        switch self {
        case .r: return "#f26d6d"; case .o: return "#f6a35a"; case .y: return "#f7d55a"; case .g: return "#6fcf7a"
        case .b: return "#5aa8f7"; case .v: return "#b872ee"; case .p: return "#f478a8"; case .x: return "#a8a8ad"
        }
    }
    var dotNS: NSColor { Tint.color(dotHex) }
    var dot: Color { Color(nsColor: dotNS) }
}

/// Пастельный оттенок всего приложения.
enum Tint: String, CaseIterable {
    case none, red, orange, yellow, green, blue, purple, pink, gray

    var pastel: Pastel? {
        switch self {
        case .none: return nil; case .red: return .r; case .orange: return .o; case .yellow: return .y; case .green: return .g
        case .blue: return .b; case .purple: return .v; case .pink: return .p; case .gray: return .x
        }
    }
    var title: String { pastel?.title ?? tr("No Color") }
    var lightHex: String { pastel?.tintLight ?? "#ffffff" }
    var darkHex: String { pastel?.tintDark ?? "#1e1e1e" }
    var swatch: Color { Color(nsColor: Tint.color(pastel?.hlLight ?? "#e5e5ea")) }

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

enum DropPos { case before, into, after }

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
    @Published var order: [String: [String]] { didSet { UserDefaults.standard.set(order, forKey: "order") } }   // раздел -> порядок элементов
    @Published var tempFolder: URL?           // папка внешнего файла, открытого через «Открыть…»

    @Published var mode: ReadMode { didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") } }
    @Published var theme: AppTheme { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") } }
    @Published var language: AppLanguage {
        didSet {
            L10n.override = language
            UserDefaults.standard.set(language.rawValue, forKey: "language")
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")   // системные меню подхватят язык при следующем запуске
        }
    }
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
        let lang = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? AppLanguage.systemDefault
        language = lang
        L10n.override = lang
        let z = d.double(forKey: "zoom")
        zoom = z > 0 ? z : 1.0
        mainURL = d.string(forKey: "mainFolder").map { URL(fileURLWithPath: $0).standardizedFileURL } ?? Self.defaultMain
        order = (d.dictionary(forKey: "order") as? [String: [String]]) ?? [:]
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

    /// Создаёт основную папку при первом запуске и кладёт туда приветственную заметку на языке интерфейса.
    static func ensureLibrary(_ url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else { return }
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        let russian = L10n.isRussian
        let name = russian ? "Добро пожаловать.md" : "Welcome.md"
        try? (russian ? welcomeRU : welcomeEN).write(to: url.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private static let welcomeEN = """
    # Welcome to MDown

    All your notes live in the main folder (`Documents/MDown` by default). Subfolders are **sections**.

    - **New note** is ⌘N, **new section** is ⇧⌘N. The new item appears in the list right away, ready to be named.
    - Right-click (two fingers) the list for the same menu, plus Rename, Color and Move to Trash.
    - Drag notes onto sections to move them, or between rows to reorder.
    - The pencil button (⌘E) turns editing on. In Pretty view click a paragraph (or double-click the text); in Source you edit the whole text. The split button shows source and result side by side.
    - Select text and right-click with two fingers for the formatting menu: heading, bold, italic, highlight color.
    - ⌘F searches, ⌘Z undoes.
    - Settings (⌘,): main folder, extra folders, theme color and language.
    """

    private static let welcomeRU = """
    # Добро пожаловать в MDown

    Все заметки живут в основной папке (по умолчанию `Documents/MDown`). Подпапки — это **разделы**.

    - **Новая заметка** — ⌘N, **новый раздел** — ⇧⌘N. Новый элемент сразу появляется в списке, и его можно назвать.
    - Правый клик (два пальца) по списку — то же меню, а ещё «Переименовать», «Цвет» и «В Корзину».
    - Перетаскивайте заметки на разделы, чтобы перенести, или между строками, чтобы поменять порядок.
    - Кнопка с карандашом (⌘E) включает правку. В «Красиво» кликните по абзацу (или дважды по тексту), в «Исходнике» правится весь текст. Кнопка со сплитом показывает исходник и результат рядом.
    - Выделите текст и кликните двумя пальцами — меню форматирования: заголовок, жирный, курсив, цвет.
    - ⌘F — поиск, ⌘Z — отмена.
    - Настройки (⌘,): основная папка, дополнительные папки, цвет темы и язык.
    """

    static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    // MARK: Корни

    func rebuildRoots() {
        var r = [Root(url: mainURL, tree: Self.buildTree(mainURL, keepEmpty: true, order: order), kind: .main)]
        for u in extraFolders where u.path != mainURL.path {
            r.append(Root(url: u, tree: Self.buildTree(u, keepEmpty: true, order: order), kind: .extra))
        }
        if let t = tempFolder, !r.contains(where: { $0.url.path == t.path }) {
            r.append(Root(url: t, tree: Self.buildTree(t, keepEmpty: false, order: order), kind: .temp))
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
        panel.message = tr("Choose a markdown file or folder")
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
        guard let url = pickFolder(message: tr("Choose the main folder for your notes")) else { return }
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
        guard let url = pickFolder(message: tr("Add a folder with notes")) else { return }
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
        let url = uniqueURL(in: folder, name: tr("New Note"), ext: "md")
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
        let url = uniqueURL(in: folder, name: tr("New Section"), ext: nil)
        do { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false) } catch { NSSound.beep(); return }
        expanded.insert(folder.path)
        expandAncestors(of: url.path)
        rebuildRoots()
        selection = url.path
        renaming = url.path
    }

    func setLabel(_ path: String, _ tag: Pastel?) { labels[path] = tag?.rawValue }

    /// Своя метка элемента или метка ближайшего раздела выше: положили заметку в «синий» раздел — она тоже синяя.
    func labelTag(for path: String) -> Pastel? {
        guard let root = root(containing: path) else { return nil }
        var p = path
        while true {
            if let k = labels[p], let t = Pastel(rawValue: k) { return t }
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
        let parent = old.deletingLastPathComponent().path
        if var list = order[parent], let k = list.firstIndex(of: old.lastPathComponent) {
            list[k] = new.lastPathComponent
            order[parent] = list
        }
        relocate(old: old.path, new: new.path)
        rebuildRoots()
    }

    /// Обновляет все ссылки на путь (открытый файл, выбор, метки, порядок, выделения) после переименования или переноса.
    private func relocate(old: String, new: String) {
        moveHighlights(from: old, to: new)
        func remap(_ p: String) -> String? {
            p == old || p.hasPrefix(old + "/") ? new + String(p.dropFirst(old.count)) : nil
        }
        if let f = fileURL, let np = remap(f.path) {
            fileURL = URL(fileURLWithPath: np)
            UserDefaults.standard.set(np, forKey: "lastFile")
        }
        if let s = selection, let np = remap(s) { selection = np }
        labels = Dictionary(labels.map { (remap($0.key) ?? $0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
        order = Dictionary(order.map { (remap($0.key) ?? $0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
        expanded = Set(expanded.map { remap($0) ?? $0 })
    }

    // MARK: Перетаскивание в списке

    func children(ofFolder path: String) -> [FileNode] {
        if let r = roots.first(where: { $0.url.path == path }) { return r.tree }
        func find(_ nodes: [FileNode]) -> [FileNode]? {
            for n in nodes {
                if n.id == path { return n.children ?? [] }
                if let c = n.children, let f = find(c) { return f }
            }
            return nil
        }
        for r in roots { if let f = find(r.tree) { return f } }
        return []
    }

    /// Бросили `src` на строку `node`: внутрь раздела, перед или после строки.
    func drop(_ src: String, on node: FileNode, position: DropPos) {
        guard src != node.id else { return }
        switch position {
        case .into where node.isDir:
            place(src, in: URL(fileURLWithPath: node.id), before: nil)
        case .into, .before, .after:
            let parent = (node.id as NSString).deletingLastPathComponent
            let sibs = children(ofFolder: parent).filter { $0.id != src }
            let idx = sibs.firstIndex(where: { $0.id == node.id })
            var before: String?
            if position == .after {
                if let idx, idx + 1 < sibs.count { before = sibs[idx + 1].name }
            } else { before = node.name }
            place(src, in: URL(fileURLWithPath: parent), before: before)
        }
    }

    /// Переносит элемент в папку (если нужно) и ставит его перед `before` (или в конец).
    func place(_ src: String, in dest: URL, before: String?) {
        saveNow()
        let fm = FileManager.default
        guard fm.fileExists(atPath: src) else { return }
        if dest.path == src || dest.path.hasPrefix(src + "/") { NSSound.beep(); return }   // раздел нельзя внутрь самого себя
        let srcURL = URL(fileURLWithPath: src)
        var name = srcURL.lastPathComponent
        if srcURL.deletingLastPathComponent().path != dest.path {
            var target = dest.appendingPathComponent(name)
            if fm.fileExists(atPath: target.path) {
                let ext = srcURL.pathExtension
                target = uniqueURL(in: dest, name: ext.isEmpty ? name : srcURL.deletingPathExtension().lastPathComponent,
                                   ext: ext.isEmpty ? nil : ext)
            }
            do { try fm.moveItem(at: srcURL, to: target) } catch { NSSound.beep(); return }
            relocate(old: src, new: target.path)
            name = target.lastPathComponent
        }
        rebuildRoots()
        var names = children(ofFolder: dest.path).map(\.name).filter { $0 != name }
        if let b = before, let k = names.firstIndex(of: b) { names.insert(name, at: k) } else { names.append(name) }
        order[dest.path] = names
        expanded.insert(dest.path)
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

    static func buildTree(_ root: URL, keepEmpty: Bool, order: [String: [String]]) -> [FileNode] {
        var budget = 8000
        return build(root, depth: 0, budget: &budget, keepEmpty: keepEmpty, order: order)
    }

    private static func build(_ dir: URL, depth: Int, budget: inout Int, keepEmpty: Bool, order: [String: [String]]) -> [FileNode] {
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
                let ch = build(u, depth: depth + 1, budget: &budget, keepEmpty: keepEmpty, order: order)
                if !ch.isEmpty || keepEmpty {
                    dirs.append(FileNode(id: u.path, name: u.lastPathComponent, isDir: true, children: ch.isEmpty ? nil : ch))
                }
            } else if markdownExtensions.contains(u.pathExtension.lowercased()) {
                files.append(FileNode(id: u.path, name: u.lastPathComponent, isDir: false, children: nil))
            }
        }
        let cmp: (FileNode, FileNode) -> Bool = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let byDefault = dirs.sorted(by: cmp) + files.sorted(by: cmp)
        // порядок, заданный перетаскиванием; новые элементы идут в конец
        guard let custom = order[dir.path], !custom.isEmpty else { return byDefault }
        let index = Dictionary(custom.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return byDefault.enumerated()
            .sorted { (index[$0.element.name] ?? custom.count + $0.offset) < (index[$1.element.name] ?? custom.count + $1.offset) }
            .map(\.element)
    }
}
