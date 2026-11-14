import SwiftUI

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
                    Picker("Вид", selection: $model.mode) {
                        Label("Красиво", systemImage: "doc.richtext").tag(ReadMode.rendered)
                        Label("Исходник", systemImage: "chevron.left.forwardslash.chevron.right").tag(ReadMode.source)
                    }
                    .pickerStyle(.segmented)
                    .help("Красивое отображение или сырой markdown (⌘1 / ⌘2)")
                    .disabled(model.split)

                    Toggle(isOn: $model.split) {
                        Label("Сплит", systemImage: "rectangle.split.2x1")
                    }
                    .toggleStyle(.button)
                    .help("Исходник и результат рядом (⌥⌘E)")

                    Toggle(isOn: $model.editing) {
                        Label("Править", systemImage: model.editing ? "pencil.circle.fill" : "pencil.circle")
                    }
                    .toggleStyle(.button)
                    .help(model.editing
                          ? "Правка включена (⌘E). В «Красиво» кликните по абзацу, в «Исходнике» печатайте"
                          : "Включить правку (⌘E) или дважды кликните по тексту")

                    Menu {
                        Button("Увеличить") { model.zoomIn() }
                        Button("Уменьшить") { model.zoomOut() }
                        Button("Реальный размер") { model.zoomReset() }
                    } label: {
                        Label("Размер текста", systemImage: "textformat.size")
                    }
                    .help("Размер текста (⌘+ / ⌘− или щипок на трекпаде)")

                    Menu {
                        Picker("Тема", selection: $model.theme) {
                            ForEach(AppTheme.allCases, id: \.self) { Label($0.title, systemImage: $0.icon).tag($0) }
                        }.pickerStyle(.inline)
                    } label: {
                        Label("Тема", systemImage: model.theme.icon)
                    }
                    .help("Светлая / тёмная тема (цвет — в настройках ⌘,)")
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
                Text("Выберите заметку слева или создайте новую").font(.title3)
                HStack {
                    Button("Новая заметка") { model.createNote() }
                    Button("Новый раздел") { model.createSection() }
                    Button("Открыть файл…") { model.openPanel() }
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
                        Text("Пусто. Правый клик или «+», чтобы создать заметку или раздел.")
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
            Button("Новая заметка") { model.createNote(in: model.mainURL) }
            Button("Новый раздел") { model.createSection(in: model.mainURL) }
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
                Button("Новая заметка") { model.createNote(in: root.url) }
                Button("Новый раздел") { model.createSection(in: root.url) }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)      // без лишних стрелок
            .fixedSize()
            .help("Новая заметка или раздел в «\(root.url.lastPathComponent)»")
        }
        .contextMenu {
            Button("Новая заметка") { model.createNote(in: root.url) }
            Button("Новый раздел") { model.createSection(in: root.url) }
            Divider()
            Button("Показать в Finder") { model.reveal(root.url.path) }
            switch root.kind {
            case .extra: Button("Убрать из списка") { model.removeExtraFolder(root.url) }
            case .temp:
                Button("Закрепить папку") { model.pinTempFolder() }
                Button("Закрыть") { model.closeTempFolder() }
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

struct NodeRow: View {
    @EnvironmentObject var model: ReaderModel
    let node: FileNode

    private var title: String {
        node.isDir ? node.name : (node.name as NSString).deletingPathExtension
    }

    private func icon(_ tag: LabelTag?) -> some View {
        Image(systemName: node.isDir ? "folder" : "doc.text")
            .foregroundStyle(tag?.color ?? Color.secondary)
    }

    private func tapped() {
        model.selection = node.id
        if node.isDir {
            if model.expanded.contains(node.id) { model.expanded.remove(node.id) } else { model.expanded.insert(node.id) }
        } else {
            model.open(URL(fileURLWithPath: node.id))
        }
    }

    var body: some View {
        let tag = model.labelTag(for: node.id)
        Group {
            if model.renaming == node.id {
                HStack(spacing: 6) {
                    icon(tag)
                    RenameField(node: node, initial: title)
                }
            } else {
                HStack(spacing: 6) {
                    icon(tag)
                    Text(title).lineLimit(1)
                    Spacer(minLength: 4)
                    if let tag { Circle().fill(tag.color).frame(width: 9, height: 9) }   // точка, как тег в Finder
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())          // клик по любой части строки, в том числе по тексту
                .onTapGesture { tapped() }
            }
        }
        .contextMenu {
            if node.isDir {
                Button("Новая заметка здесь") { model.createNote(in: URL(fileURLWithPath: node.id)) }
                Button("Новый раздел внутри") { model.createSection(in: URL(fileURLWithPath: node.id)) }
                Divider()
            }
            Menu("Цвет") {
                ForEach(LabelTag.allCases, id: \.self) { t in
                    Button((model.labels[node.id] == t.rawValue ? "✓ " : "") + t.emoji + " " + t.title) { model.setLabel(node.id, t) }
                }
                Divider()
                Button("Без цвета") { model.setLabel(node.id, nil) }
            }
            Button("Переименовать") { model.beginRename(node.id) }
            Button("Показать в Finder") { model.reveal(node.id) }
            Divider()
            Button("В Корзину") { model.trash(node.id) }
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
            TextField("Найти", text: $model.searchText)
                .textFieldStyle(.plain)
                .frame(width: 190)
                .focused($focused)
                .onSubmit { model.find() }
                .onExitCommand { model.closeSearch() }
                .onChange(of: model.searchText) { _ in model.find() }
            Button { model.find(backwards: true) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
                .keyboardShortcut(.return, modifiers: .shift)
                .help("Предыдущее (⇧⌘G)")
            Button { model.find() } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
                .help("Следующее (⌘G, Enter)")
            Button { model.closeSearch() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.borderless)
                .help("Закрыть (Esc)")
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
