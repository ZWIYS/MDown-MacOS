import SwiftUI

@main
struct MDownApp: App {
    @StateObject private var model = ReaderModel()

    var body: some Scene {
        WindowGroup("MDown") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 620, minHeight: 420)
        }
        .handlesExternalEvents(matching: ["*"])
        .defaultSize(width: 1040, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(tr("New Note…")) { model.createNote() }
                    .keyboardShortcut("n")
                Button(tr("New Section…")) { model.createSection() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button(tr("Open File or Folder…")) { model.openPanel() }
                    .keyboardShortcut("o")
                Button(tr("Close Temporary Folder")) { model.closeTempFolder() }
                    .disabled(model.tempFolder == nil)
            }
            CommandGroup(replacing: .saveItem) {
                Button(tr("Save")) { model.saveNow() }
                    .keyboardShortcut("s")
            }
            CommandGroup(after: .textEditing) {
                Divider()
                Button(tr("Find…")) { model.openSearch() }.keyboardShortcut("f")
                Button(tr("Find Next")) { model.find() }.keyboardShortcut("g")
                Button(tr("Find Previous")) { model.find(backwards: true) }.keyboardShortcut("g", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Divider()
                Button(tr("View: Pretty")) { model.mode = .rendered }.keyboardShortcut("1")
                Button(tr("View: Source")) { model.mode = .source }.keyboardShortcut("2")
                Button(tr("Toggle Editing")) { model.editing.toggle() }.keyboardShortcut("e")
                Button(tr("Split: Source and Result Side by Side")) { model.split.toggle() }.keyboardShortcut("e", modifiers: [.command, .option])
                Divider()
                Button(tr("Increase Text Size")) { model.zoomIn() }.keyboardShortcut("+")
                Button(tr("Decrease Text Size")) { model.zoomOut() }.keyboardShortcut("-")
                Button(tr("Actual Size")) { model.zoomReset() }.keyboardShortcut("0")
                Divider()
                Picker(tr("Theme"), selection: $model.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
        }

        Settings {
            SettingsView().environmentObject(model)
        }
    }
}
