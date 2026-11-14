import SwiftUI
import UniformTypeIdentifiers

/// Красит само окно (включая заголовок) в цвет темы, чтобы не было полос разных оттенков.
struct WindowTint: NSViewRepresentable {
    let color: NSColor
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            view.window?.backgroundColor = color
            view.window?.titlebarAppearsTransparent = true
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: ReaderModel
    @State private var visibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 270, max: 440)
        } detail: {
            ZStack {
                Color(nsColor: model.tint.nsColor).ignoresSafeArea()
                detailContent
            }
            .overlay(alignment: .topTrailing) {
                if model.searchOpen { SearchBar().padding(.top, 10).padding(.trailing, 16) }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
            .navigationTitle(model.fileURL.map { $0.deletingPathExtension().lastPathComponent } ?? "MDown")
            .navigationSubtitle(model.fileURL?.deletingLastPathComponent().lastPathComponent ?? "")
            .toolbar {
                ToolbarItemGroup {
                    Picker(tr("View"), selection: $model.mode) {
                        Label(tr("Pretty"), systemImage: "doc.richtext").tag(ReadMode.rendered)
                        Label(tr("Source"), systemImage: "chevron.left.forwardslash.chevron.right").tag(ReadMode.source)
                    }
                    .pickerStyle(.segmented)
                    .help(tr("Pretty view or raw markdown (⌘1 / ⌘2)"))
                    .disabled(model.split)

                    Toggle(isOn: $model.split) {
                        Label(tr("Split"), systemImage: "rectangle.split.2x1")
                    }
                    .toggleStyle(.button)
                    .help(tr("Source and result side by side (⌥⌘E)"))

                    Toggle(isOn: $model.editing) {
                        Label(tr("Edit"), systemImage: model.editing ? "pencil.circle.fill" : "pencil.circle")
                    }
                    .toggleStyle(.button)
                    .help(model.editing
                          ? tr("Editing is on (⌘E). In Pretty view click a paragraph, in Source just type")
                          : tr("Turn editing on (⌘E) or double-click the text"))

                    Menu {
                        Button(tr("Increase")) { model.zoomIn() }
                        Button(tr("Decrease")) { model.zoomOut() }
                        Button(tr("Actual Size")) { model.zoomReset() }
                    } label: {
                        Label(tr("Text Size"), systemImage: "textformat.size")
                    }
                    .help(tr("Text size (⌘+ / ⌘− or pinch on the trackpad)"))

                    Menu {
                        Picker(tr("Theme"), selection: $model.theme) {
                            ForEach(AppTheme.allCases, id: \.self) { Label($0.title, systemImage: $0.icon).tag($0) }
                        }.pickerStyle(.inline)
                    } label: {
                        Label(tr("Theme"), systemImage: model.theme.icon)
                    }
                    .help(tr("Light / dark theme (color is in Settings ⌘,)"))
                }
            }
        }
        .background(WindowTint(color: model.tint.nsColor))
        .preferredColorScheme(model.theme.scheme)
        .onOpenURL { model.open($0) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            model.saveNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.saveNow()
        }
    }

    @ViewBuilder private var detailContent: some View {
        if model.fileURL == nil {
            VStack(spacing: 14) {
                Image(systemName: "doc.text").font(.system(size: 44)).foregroundStyle(.secondary)
                Text(tr("Select a note on the left or create a new one")).font(.title3)
                HStack {
                    Button(tr("New Note")) { model.createNote() }
                    Button(tr("New Section")) { model.createSection() }
                    Button(tr("Open File…")) { model.openPanel() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.split {
            HSplitView {
                EditorView(model: model).frame(minWidth: 260)
                MarkdownWebView(model: model).frame(minWidth: 260)
            }
        } else if model.mode == .source {
            EditorView(model: model)
        } else {
            MarkdownWebView(model: model)
        }
    }
}

// MARK: - Боковая панель

struct SidebarView: View {
    @EnvironmentObject var model: ReaderModel

    var body: some View {
        List(selection: $model.selection) {
            ForEach(model.roots) { root in
                Section {
                    ForEach(root.tree) { NodeView(node: $0) }
                    if root.tree.isEmpty {
                        Text(tr("Empty. Right-click or “+” to create a note or section."))
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                } header: {
                    RootHeader(root: root)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background { Color(nsColor: model.tint.sidebarColor).ignoresSafeArea() }
        .contextMenu {   // правый клик / два пальца по пустому месту списка
            Button(tr("New Note")) { model.createNote(in: model.mainURL) }
            Button(tr("New Section")) { model.createSection(in: model.mainURL) }
        }
        .onChange(of: model.selection) { path in
            guard let path, !ReaderModel.isDirectory(path) else { return }
            model.open(URL(fileURLWithPath: path))
        }
    }
}

struct RootHeader: View {
    @EnvironmentObject var model: ReaderModel
    let root: Root

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: root.kind == .main ? "books.vertical" : "folder")
            Text(root.url.lastPathComponent).lineLimit(1)
            Spacer()
            Menu {
                Button(tr("New Note")) { model.createNote(in: root.url) }
                Button(tr("New Section")) { model.createSection(in: root.url) }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)      // без лишних стрелок
            .fixedSize()
            .help(trf("New note or section in “%@”", root.url.lastPathComponent))
        }
        .contentShape(Rectangle())
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            guard let item = providers.first else { return false }
            _ = item.loadObject(ofClass: NSString.self) { obj, _ in
                guard let path = obj as? String else { return }
                DispatchQueue.main.async { model.place(path, in: root.url, before: nil) }
            }
            return true
        }
        .contextMenu {
            Button(tr("New Note")) { model.createNote(in: root.url) }
            Button(tr("New Section")) { model.createSection(in: root.url) }
            Divider()
            Button(tr("Show in Finder")) { model.reveal(root.url.path) }
            switch root.kind {
            case .extra: Button(tr("Remove from List")) { model.removeExtraFolder(root.url) }
            case .temp:
                Button(tr("Pin Folder")) { model.pinTempFolder() }
                Button(tr("Close")) { model.closeTempFolder() }
            case .main: EmptyView()
            }
        }
    }
}

struct NodeView: View {
    @EnvironmentObject var model: ReaderModel
    let node: FileNode

    var body: some View {
        if node.isDir {
            DisclosureGroup(isExpanded: Binding(
                get: { model.expanded.contains(node.id) },
                set: { if $0 { model.expanded.insert(node.id) } else { model.expanded.remove(node.id) } }
            )) {
                ForEach(node.children ?? []) { NodeView(node: $0) }
            } label: {
                NodeRow(node: node).tag(node.id)
            }
        } else {
            NodeRow(node: node).tag(node.id)
        }
    }
}

/// Точка-метка, как тег в Finder.
struct TagDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color)
            .frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.14), lineWidth: 0.5))
    }
}

/// Круглая иконка для пунктов меню «Цвет» (с галочкой у выбранного).
func tagMenuImage(_ color: NSColor, checked: Bool) -> NSImage {
    let img = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { r in
        let circle = NSBezierPath(ovalIn: r.insetBy(dx: 1, dy: 1))
        color.setFill(); circle.fill()
        NSColor.black.withAlphaComponent(0.18).setStroke(); circle.lineWidth = 0.5; circle.stroke()
        if checked {
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: 4, y: 7)); tick.line(to: NSPoint(x: 6.2, y: 4.8)); tick.line(to: NSPoint(x: 10, y: 9.6))
            NSColor.white.setStroke(); tick.lineWidth = 1.6; tick.lineCapStyle = .round; tick.lineJoinStyle = .round; tick.stroke()
        }
        return true
    }
    img.isTemplate = false
    return img
}

/// Бросание на строку списка: верхняя часть — перед строкой, нижняя — после, середина раздела — внутрь.
struct RowDropDelegate: DropDelegate {
    let model: ReaderModel
    let node: FileNode
    let height: CGFloat
    @Binding var hover: DropPos?

    private func position(_ info: DropInfo) -> DropPos {
        let y = info.location.y
        if node.isDir { return y < height * 0.25 ? .before : (y > height * 0.75 ? .after : .into) }
        return y < height / 2 ? .before : .after
    }
    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.plainText]) }
    func dropEntered(info: DropInfo) { hover = position(info) }
    func dropUpdated(info: DropInfo) -> DropProposal? { hover = position(info); return DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { hover = nil }
    func performDrop(info: DropInfo) -> Bool {
        let pos = position(info)
        hover = nil
        guard let item = info.itemProviders(for: [.plainText]).first else { return false }
        _ = item.loadObject(ofClass: NSString.self) { obj, _ in
            guard let path = obj as? String else { return }
            DispatchQueue.main.async { model.drop(path, on: node, position: pos) }
        }
        return true
    }
}

struct NodeRow: View {
    @EnvironmentObject var model: ReaderModel
    let node: FileNode
    @State private var hover: DropPos?
    @State private var height: CGFloat = 26

    private var title: String {
        node.isDir ? node.name : (node.name as NSString).deletingPathExtension
    }

    private var icon: some View {
        Image(systemName: node.isDir ? "folder" : "doc.text").foregroundStyle(.secondary)
    }

    private func tapped() {
        model.selection = node.id
        if node.isDir {
            if model.expanded.contains(node.id) { model.expanded.remove(node.id) } else { model.expanded.insert(node.id) }
        } else {
            model.open(URL(fileURLWithPath: node.id))
        }
    }

    @ViewBuilder private var dropIndicator: some View {
        switch hover {
        case .before: VStack { Rectangle().fill(Color.accentColor).frame(height: 2); Spacer() }
        case .after: VStack { Spacer(); Rectangle().fill(Color.accentColor).frame(height: 2) }
        case .into: RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2)
        case nil: EmptyView()
        }
    }

    var body: some View {
        let tag = model.labelTag(for: node.id)
        Group {
            if model.renaming == node.id {
                HStack(spacing: 6) {
                    icon
                    RenameField(node: node, initial: title)
                }
            } else {
                HStack(spacing: 6) {
                    icon
                    Text(title).lineLimit(1)
                    if let tag { TagDot(color: tag.dot) }      // точка рядом с названием, как в Finder
                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())                      // клик по любой части строки
                .onTapGesture { tapped() }
                .onDrag { NSItemProvider(object: node.id as NSString) }
            }
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { height = g.size.height }
                .onChange(of: g.size.height) { height = $0 }
        })
        .overlay(dropIndicator.allowsHitTesting(false))
        .onDrop(of: [.plainText], delegate: RowDropDelegate(model: model, node: node, height: height, hover: $hover))
        .contextMenu {
            if node.isDir {
                Button(tr("New Note Here")) { model.createNote(in: URL(fileURLWithPath: node.id)) }
                Button(tr("New Section Inside")) { model.createSection(in: URL(fileURLWithPath: node.id)) }
                Divider()
            }
            Menu(tr("Color")) {
                ForEach(Pastel.allCases, id: \.self) { t in
                    Button { model.setLabel(node.id, t) } label: {
                        Label {
                            Text(t.title)
                        } icon: {
                            Image(nsImage: tagMenuImage(t.dotNS, checked: model.labels[node.id] == t.rawValue)).renderingMode(.original)
                        }
                    }
                }
                Divider()
                Button(tr("No Color")) { model.setLabel(node.id, nil) }
            }
            Button(tr("Rename")) { model.beginRename(node.id) }
            Button(tr("Show in Finder")) { model.reveal(node.id) }
            Divider()
            Button(tr("Move to Trash")) { model.trash(node.id) }
        }
    }
}

/// Поле переименования прямо в списке (как в Finder): имя выделено, Enter применяет, Esc отменяет.
struct RenameField: View {
    @EnvironmentObject var model: ReaderModel
    let node: FileNode
    let initial: String
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .onSubmit { model.commitRename(node.id, to: text) }
            .onExitCommand { model.cancelRename() }
            .onChange(of: focused) { isFocused in
                if !isFocused, model.renaming == node.id { model.commitRename(node.id, to: text) }
            }
            .onAppear {
                text = initial
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    focused = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        (NSApp.keyWindow?.firstResponder as? NSText)?.selectAll(nil)
                    }
                }
            }
    }
}

// MARK: - Поиск (⌘F)

struct SearchBar: View {
    @EnvironmentObject var model: ReaderModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(tr("Find"), text: $model.searchText)
                .textFieldStyle(.plain)
                .frame(width: 190)
                .focused($focused)
                .onSubmit { model.find() }
                .onExitCommand { model.closeSearch() }
                .onChange(of: model.searchText) { _ in model.find() }
            Button { model.find(backwards: true) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
                .keyboardShortcut(.return, modifiers: .shift)
                .help(tr("Previous (⇧⌘G)"))
            Button { model.find() } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
                .help(tr("Next (⌘G, Enter)"))
            Button { model.closeSearch() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.borderless)
                .help(tr("Close (Esc)"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .onAppear { focused = true }
        .onChange(of: model.searchFocusTick) { _ in focused = true }
    }
}
