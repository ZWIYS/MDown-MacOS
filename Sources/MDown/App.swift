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
                Button("Новая заметка…") { model.createNote() }
                    .keyboardShortcut("n")
                Button("Новый раздел…") { model.createSection() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("Открыть файл или папку…") { model.openPanel() }
                    .keyboardShortcut("o")
                Button("Закрыть временную папку") { model.closeTempFolder() }
                    .disabled(model.tempFolder == nil)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Сохранить") { model.saveNow() }
                    .keyboardShortcut("s")
            }
            CommandGroup(after: .textEditing) {
                Divider()
                Button("Найти…") { model.openSearch() }.keyboardShortcut("f")
                Button("Найти далее") { model.find() }.keyboardShortcut("g")
                Button("Найти ранее") { model.find(backwards: true) }.keyboardShortcut("g", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Divider()
                Button("Вид «Красиво»") { model.mode = .rendered }.keyboardShortcut("1")
                Button("Вид «Исходник»") { model.mode = .source }.keyboardShortcut("2")
                Button("Включить / выключить правку") { model.editing.toggle() }.keyboardShortcut("e")
                Button("Сплит: исходник и результат рядом") { model.split.toggle() }.keyboardShortcut("e", modifiers: [.command, .option])
                Divider()
                Button("Увеличить текст") { model.zoomIn() }.keyboardShortcut("+")
                Button("Уменьшить текст") { model.zoomOut() }.keyboardShortcut("-")
                Button("Реальный размер") { model.zoomReset() }.keyboardShortcut("0")
                Divider()
                Picker("Тема", selection: $model.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
        }

        Settings {
            SettingsView().environmentObject(model)
        }
    }
}
