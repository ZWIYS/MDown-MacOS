import SwiftUI

/// Окно настроек (⌘,): папки и цвет темы.
struct SettingsView: View {
    @EnvironmentObject var model: ReaderModel

    var body: some View {
        Form {
            Section(tr("Main Folder")) {
                HStack {
                    Image(systemName: "books.vertical")
                    Text(model.mainURL.path).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button(tr("Choose…")) { model.chooseMainFolder() }
                }
                if model.mainURL.path != ReaderModel.defaultMain.path {
                    Button(tr("Restore Documents/MDown")) { model.resetMainFolder() }
                }
                Text(tr("Your notes live here. Subfolders are sections."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(tr("Extra Folders")) {
                if model.extraFolders.isEmpty {
                    Text(tr("None yet. Add folders to work with several places at once; they appear in the sidebar."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.extraFolders, id: \.path) { url in
                    HStack {
                        Image(systemName: "folder")
                        Text(url.path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button { model.removeExtraFolder(url) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .help(tr("Remove from list (files are not deleted)"))
                    }
                }
                Button(tr("Add Folder…")) { model.addExtraFolder() }
            }

            Section(tr("Language")) {
                Picker(tr("Language"), selection: $model.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                Text(tr("Interface language. Menus like Edit and Window switch after the app is restarted."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(tr("Theme Color")) {
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
                Text(trf("Background tint for reading and editing: %@.", model.tint.title))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}
