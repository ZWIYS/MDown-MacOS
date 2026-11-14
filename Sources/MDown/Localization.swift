import Foundation

/// Язык интерфейса: английский или русский.
enum AppLanguage: String, CaseIterable {
    case en, ru
    var title: String { self == .en ? "English" : "Русский" }

    /// Язык по умолчанию при первом запуске: русский, если система русская, иначе английский.
    static var systemDefault: AppLanguage {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("ru") ? .ru : .en
    }
}

enum L10n {
    /// Выбранный язык (задаётся моделью).
    static var override: AppLanguage = AppLanguage.systemDefault
    static var isRussian: Bool { override == .ru }
}

/// Перевод строки. Ключ — английский текст; для русского ищется перевод, для остальных языков остаётся английский.
func tr(_ key: String) -> String {
    L10n.isRussian ? (ruStrings[key] ?? key) : key
}

func trf(_ key: String, _ args: CVarArg...) -> String {
    String(format: tr(key), arguments: args)
}

private let ruStrings: [String: String] = [
    "Main Folder": "Основная папка",
    "Choose…": "Выбрать…",
    "Restore Documents/MDown": "Вернуть Documents/MDown",
    "Your notes live here. Subfolders are sections.": "Здесь живут заметки. Подпапки — это разделы.",
    "Extra Folders": "Дополнительные папки",
    "None yet. Add folders to work with several places at once; they appear in the sidebar.": "Пока нет. Добавьте папки, чтобы работать с несколькими местами сразу, они появятся в боковой панели.",
    "Remove from list (files are not deleted)": "Убрать из списка (файлы не удаляются)",
    "Add Folder…": "Добавить папку…",
    "Theme Color": "Цвет темы",
    "New Note…": "Новая заметка…",
    "New Section…": "Новый раздел…",
    "Open File or Folder…": "Открыть файл или папку…",
    "Close Temporary Folder": "Закрыть временную папку",
    "Save": "Сохранить",
    "Find…": "Найти…",
    "Find Next": "Найти далее",
    "Find Previous": "Найти ранее",
    "View: Pretty": "Вид «Красиво»",
    "View: Source": "Вид «Исходник»",
    "Toggle Editing": "Включить / выключить правку",
    "Split: Source and Result Side by Side": "Сплит: исходник и результат рядом",
    "Increase Text Size": "Увеличить текст",
    "Decrease Text Size": "Уменьшить текст",
    "Actual Size": "Реальный размер",
    "Theme": "Тема",
    "Plain Text": "Обычный текст",
    "Heading 1": "Заголовок 1",
    "Heading 2": "Заголовок 2",
    "Heading 3": "Заголовок 3",
    "Heading": "Заголовок",
    "Bold": "Жирный",
    "Italic": "Курсив",
    "Strikethrough": "Зачёркнутый",
    "Code": "Код",
    "Quote": "Цитата",
    "Bulleted List": "Маркированный список",
    "Highlight Color": "Выделить цветом",
    "Remove Highlight": "Убрать выделение",
    "Follow System": "Как в системе",
    "Light": "Светлая",
    "Dark": "Тёмная",
    "Red": "Красный",
    "Orange": "Оранжевый",
    "Yellow": "Жёлтый",
    "Green": "Зелёный",
    "Blue": "Синий",
    "Purple": "Фиолетовый",
    "Pink": "Розовый",
    "Gray": "Серый",
    "No Color": "Без цвета",
    "Choose a markdown file or folder": "Выберите markdown-файл или папку",
    "Choose the main folder for your notes": "Выберите основную папку для заметок",
    "Add a folder with notes": "Добавьте папку с заметками",
    "New Note": "Новая заметка",
    "New Section": "Новый раздел",
    "View": "Вид",
    "Pretty": "Красиво",
    "Source": "Исходник",
    "Pretty view or raw markdown (⌘1 / ⌘2)": "Красивое отображение или сырой markdown (⌘1 / ⌘2)",
    "Split": "Сплит",
    "Source and result side by side (⌥⌘E)": "Исходник и результат рядом (⌥⌘E)",
    "Edit": "Править",
    "Editing is on (⌘E). In Pretty view click a paragraph, in Source just type": "Правка включена (⌘E). В «Красиво» кликните по абзацу, в «Исходнике» печатайте",
    "Turn editing on (⌘E) or double-click the text": "Включить правку (⌘E) или дважды кликните по тексту",
    "Increase": "Увеличить",
    "Decrease": "Уменьшить",
    "Text Size": "Размер текста",
    "Text size (⌘+ / ⌘− or pinch on the trackpad)": "Размер текста (⌘+ / ⌘− или щипок на трекпаде)",
    "Light / dark theme (color is in Settings ⌘,)": "Светлая / тёмная тема (цвет — в настройках ⌘,)",
    "Select a note on the left or create a new one": "Выберите заметку слева или создайте новую",
    "Open File…": "Открыть файл…",
    "Empty. Right-click or “+” to create a note or section.": "Пусто. Правый клик или «+», чтобы создать заметку или раздел.",
    "Show in Finder": "Показать в Finder",
    "Remove from List": "Убрать из списка",
    "Pin Folder": "Закрепить папку",
    "Close": "Закрыть",
    "New Note Here": "Новая заметка здесь",
    "New Section Inside": "Новый раздел внутри",
    "Color": "Цвет",
    "Rename": "Переименовать",
    "Move to Trash": "В Корзину",
    "Find": "Найти",
    "Previous (⇧⌘G)": "Предыдущее (⇧⌘G)",
    "Next (⌘G, Enter)": "Следующее (⌘G, Enter)",
    "Close (Esc)": "Закрыть (Esc)",
    "Language": "Язык",
    "List": "Список",
    "Write here…": "Пишите здесь…",
    "Click to write…": "Нажмите, чтобы писать…",
    "Couldn't find this spot in the source. Select text inside a single paragraph without formatting, or turn editing on.": "Не нашёл это место в исходнике. Выделите текст внутри одного абзаца без форматирования или включите правку.",
    "Interface language. Menus like Edit and Window switch after the app is restarted.": "Язык интерфейса. Системные меню («Правка», «Окно») сменят язык после перезапуска приложения.",
    "New note or section in “%@”": "Новая заметка или раздел в «%@»",
    "Background tint for reading and editing: %@.": "Оттенок фона для чтения и редактирования: %@.",
]
