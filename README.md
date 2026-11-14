# MDown

**Version 1.5** · by Peter Plyuvkov & Claude · English | [Русский](README.ru.md)

**MDown** is a simple native macOS app for reading, writing and organizing markdown notes in sections. Built with SwiftUI + WebKit, no third-party dependencies, no internet required.

> The app's interface is currently in Russian.

## Features

### Notes library and sections
- On first launch MDown creates a main folder, **`~/Documents/MDown`**. All notes live there and **subfolders are sections**. They are plain `.md` files, so you can open them in any other editor or sync them with iCloud/git.
- **New note** (⌘N) and **new section** (⇧⌘N) appear in the sidebar immediately and you name them right there, like in Finder: the name is selected, Enter confirms, Esc keeps the default.
- Create from the File menu, the "+" button in a folder header, or by **right-clicking (two fingers)** the list. Right-clicking a note or section also offers Rename, Show in Finder, Color and Move to Trash.
- **Drag and drop** in the sidebar: drag a note onto a section to move it there, or drop it between rows to reorder. Order is remembered. Dragging a section works the same way.
- **Color labels.** Right-click → Color puts a Finder-style colored dot next to the name. Notes inside a colored section inherit its color, so drop a note into the "blue" section and it becomes blue. A note's own color wins.
- Click anywhere on a row (including the text) to open it, click a section to expand it.
- **Open any file or folder** outside the library with File → Open (⌘O). It appears as a temporary folder in the sidebar that you can pin or close (right-click its header).

### Settings (⌘,)
- **Main folder**: any folder instead of `Documents/MDown`.
- **Extra folders**: add as many as you like. They all show in the sidebar at the same time, with the same sections, drag and drop and note creation.
- **Theme color**: a pastel tint for the whole app (window, sidebar, title bar, reading and editing). Eight colors based on macOS system colors plus pink: red, orange, yellow, green, blue, purple, pink, gray, or no tint. In dark theme the tints are muted.

### Reading and editing
- **"Красиво" / pretty (⌘1)**: rendered markdown. **"Исходник" / source (⌘2)**: raw markdown.
- **Pencil (⌘E)** turns editing on in both views (in pretty view a double click on the text also turns it on):
  - in pretty view click a paragraph, heading, list or table and that block turns into a field with its source, so you type in place. Esc, ⌘Enter or a click elsewhere applies the edit. Clicking the empty space below the text adds a new block;
  - in source view you edit the whole text (undo, native text editing).
- **Split view** (toolbar button, ⌥⌘E): source on the left, result on the right. Turns editing on.
- **Search ⌘F**: a search bar in the corner of the window, works in both views (Enter or ⌘G next, ⇧Enter or ⇧⌘G previous, Esc closes).
- **⌘Z / ⇧⌘Z** undo and redo edits and formatting, including in pretty view.
- Autosave: 0.8 s after you stop typing, when you switch to another app, and on quit (⌘S works too).

### Formatting via right-click
Select text and right-click (two fingers) to get a formatting menu, in both pretty and source views:
- heading 1-3 or plain text, **bold**, *italic*, ~~strikethrough~~, `code`, quote, list;
- highlight with one of eight pastel colors (the macOS palette plus pink) and "remove highlight";
- applying bold or italic to already formatted text removes the formatting. ⌘B and ⌘I work in source view.

How highlights are stored:
- in **pretty view** (editing off) highlights are stored separately, in `~/Library/Application Support/MDown/highlights.json`, and your `.md` stays untouched;
- in **source view** and in the edit field a highlight is written into the text as `<mark data-c="y">…</mark>` (GitHub shows it as a plain highlight).

### Appearance
- **Text size**: pinch on the trackpad (the text reflows like Safari's reader mode), or ⌘+, ⌘− and ⌘0.
- **Theme**: follow the system, light or dark.
- Relative links to other `.md` files open inside the app, images next to the file are shown, external links open in the browser.

Supported markdown: headings, lists (nested, numbered, task lists), tables with alignment, quotes, code blocks, links (including reference-style), images, `**bold**`, `*italic*`, `~~strikethrough~~`, `` `code` ``, horizontal rules, front matter (hidden), `<mark>`, some inline HTML (`<kbd>`, `<br>`, `<details>`, etc). Not supported: footnotes, syntax highlighting, diagrams.

## Requirements

- macOS 13 or newer
- Swift 5.9+ (Command Line Tools are enough, Xcode is not needed): `xcode-select --install`

## Installation

```bash
git clone https://github.com/ZWIYS/MDown-MacOS.git
cd MDown-MacOS
./install.sh
```

The script builds the app and installs it to `/Applications/MDown.app` (it also removes the old "MD Reader" if present). After that MDown is available in Launchpad and Spotlight. To keep it in the Dock, launch it and choose Options → Keep in Dock from the Dock icon menu.

The app is ad-hoc signed (no developer certificate). If macOS refuses to open it, right-click the app and choose Open.

Build only, without installing:

```bash
./build.sh          # creates ./MDown.app
open MDown.app
```

Open a specific file on launch:

```bash
open MDown.app --args /path/to/file.md
```

## Project structure

```
Package.swift            SwiftPM manifest (one executable target, MDown)
Info.plist               .app metadata, icon, .md association, version
build.sh                 swift build + packaging into MDown.app + ad-hoc signing
install.sh               build.sh + copy to /Applications
Resources/AppIcon.icns   app icon
tools/make_icon.swift    script that draws the 1024x1024 icon (swift tools/make_icon.swift out.png)
sample/                  sample markdown files for testing
Sources/MDown/
  App.swift              entry point, File and View menus, shortcuts, settings window
  ContentView.swift      window: toolbar, layout (view/split), search bar, sidebar, drag and drop, inline rename
  SettingsView.swift     settings: main and extra folders, theme color
  Model.swift            state: root folders, sections, files, ordering, labels, palette, saving, highlights
  EditorView.swift       "source" view on NSTextView + formatting menu, ⌘B/⌘I
  WebView.swift          WKWebView: pinch zoom, links, local images, page <-> app bridge
  Template.swift         HTML/CSS and embedded JS: markdown parser, block editing, formatting menu, highlights, undo
```

## How it works

- **Rendering.** Markdown is converted to HTML by a small built-in JavaScript parser ([Template.swift](Sources/MDown/Template.swift)) and shown in a `WKWebView`. The theme follows the system via `prefers-color-scheme`, the app theme is set through `preferredColorScheme`, and the tint through the CSS variables `--bg-l` / `--bg-d`.
- **Palette.** One `Pastel` enum in [Model.swift](Sources/MDown/Model.swift) defines the eight colors and is used for the theme tint, text highlights and color labels.
- **In-place editing.** The parser remembers the source line range of every top-level block. Clicking a block swaps it for a `<textarea>`; when you finish, that range is replaced with the new text, the page is redrawn, and the full text is sent to the app through a `WKScriptMessageHandler` and saved to the file. Page-level undo/redo keeps a history of the document text.
- **Formatting.** In pretty view the selected fragment is found in the source of its block (taking the occurrence number into account) and wrapped in markers; if it can't be located exactly (for example the selection crosses a link) a hint is shown. In source view the menu is added to `NSTextView` (`menu(for:)`).
- **Ordering and moving.** Drag and drop moves files on disk; the order within a folder is stored in the app's preferences (the file system has no order), and new items go to the end.
- **Zoom.** A pinch is caught in a `WKWebView` subclass (`magnify(with:)`) and changes `pageZoom`, so the text reflows.
- **Local files.** The page is loaded with the base `mdlocal://doc/<folder path>/` and a `WKURLSchemeHandler` serves files from disk, so relative image paths work.
- **Highlights.** Stored as offsets in the page text plus the fragment itself. When the document changes the offsets are re-anchored by searching for the fragment; renaming or moving a file or section moves its highlights along.

## Known limitations

- The markdown parser is simplified and not fully CommonMark compliant.
- In-place editing works on top-level blocks: a list or table is edited as a whole.
- In pretty view, formatting applies to a selection inside a single block; a selection spanning several paragraphs does not open the formatting menu.
- Autosave writes straight to the file without asking (deleted items go to the Trash).
- Pretty-view highlights are tied to the file path: if you rename or move a file outside the app, they are lost.
- The interface language is Russian only for now.

## License

MIT, see [LICENSE](LICENSE).

© Peter Plyuvkov & Claude
