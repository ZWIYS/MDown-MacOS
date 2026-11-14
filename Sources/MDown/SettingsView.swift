import SwiftUI

/// Окно настроек (⌘,): папки и цвет темы.
struct SettingsView: View {
    @EnvironmentObject var model: ReaderModel

    var body: some View {
        Form {
            Section("Основная папка") {
                HStack {
                    Image(systemName: "books.vertical")
                    Text(model.mainURL.path).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Выбрать…") { model.chooseMainFolder() }
                }
                if model.mainURL.path != ReaderModel.defaultMain.path {
                    Button("Вернуть Documents/MDown") { model.resetMainFolder() }
                }
                Text("Здесь живут заметки. Подпапки — это разделы.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Дополнительные папки") {
                if model.extraFolders.isEmpty {
                    Text("Пока нет. Добавьте папки, чтобы работать с несколькими местами сразу, они появятся в боковой панели.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.extraFolders, id: \.path) { url in
                    HStack {
                        Image(systemName: "folder")
                        Text(url.path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button { model.removeExtraFolder(url) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .help("Убрать из списка (файлы не удаляются)")
                    }
                }
                Button("Добавить папку…") { model.addExtraFolder() }
            }

            Section("Цвет темы") {
                HStack(spacing: 12) {
                    ForEach(Tint.allCases, id: \.self) { t in
                        Button { model.tint = t } label: {
                            Circle()
                                .fill(t.swatch)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                                .overlay {
                                    if model.tint == t { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.black.opacity(0.6)) }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(t.title)
                    }
                }
                Text("Оттенок фона для чтения и редактирования: \(model.tint.title).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}
