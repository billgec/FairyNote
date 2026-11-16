import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case all
    case folder(Folder)
}

/// Bibliothek: links Ordner, rechts Notizbücher als Grid.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @AppStorage(AppTheme.nameKey) private var userName = ""
    @State private var showSettings = false
    @Query(sort: \Notebook.modifiedAt, order: .reverse) private var notebooks: [Notebook]
    @Query(sort: \Folder.name) private var folders: [Folder]

    @State private var selection: SidebarItem? = .all
    @State private var path = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showNewNotebook = false

    // Umbenennen / Neuer Ordner
    @State private var nameEdit: NameEdit?
    @State private var nameText = ""
    @State private var isEditingName = false

    // Löschen
    @State private var deleteTarget: DeleteTarget?
    @State private var isDeleting = false

    // Import / Export
    @State private var showImporter = false
    @State private var shareItem: ShareItem?
    @State private var transferError: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 28)]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack(path: $path) {
                grid
                    .navigationDestination(for: Notebook.self) { NotebookView(notebook: $0) }
            }
        }
        .onChange(of: path.count) { _, count in
            withAnimation { columnVisibility = count > 0 ? .detailOnly : .automatic }
        }
        .onChange(of: selection) { path = NavigationPath() }
        .sheet(isPresented: $showNewNotebook) {
            NewNotebookSheet(defaultTitle: "Notizbuch \(notebooks.count + 1)", onCreate: createNotebook)
        }
        .alert(nameEdit?.title ?? "", isPresented: $isEditingName) {
            TextField("Name", text: $nameText)
            Button("Abbrechen", role: .cancel) {}
            Button("Sichern", action: applyNameEdit)
        }
        .confirmationDialog(deleteTarget?.title ?? "", isPresented: $isDeleting, titleVisibility: .visible,
                            presenting: deleteTarget) { target in
            Button("Löschen", role: .destructive) { delete(target) }
        } message: { target in
            Text(target.message)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: NotebookImporter.importableTypes,
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error): transferError = error.localizedDescription
            }
        }
        // Dateien, die über „Teilen › FairyNote“ (z. B. aus GoodNotes oder Dateien) geöffnet werden.
        .onOpenURL { importFiles([$0]) }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert("Import/Export", isPresented: Binding(get: { transferError != nil },
                                                     set: { if !$0 { transferError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transferError ?? "")
        }
    }

    // MARK: Sidebar

    private var rootFolders: [Folder] {
        folders.filter { $0.parent == nil }
    }

    /// Alle Ordner als flache Liste mit vollem Pfad, für "Verschieben".
    private var allFolders: [Folder] {
        rootFolders.flatMap(\.subtree)
    }

    private var sidebar: some View {
        List(selection: $selection) {
            HStack(spacing: 10) {
                Image(systemName: theme.motif)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(theme.accent.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: theme.accent.opacity(0.35), radius: 4, y: 2)
                Text("FairyNote")
                    .font(theme.title(24))
                    .foregroundStyle(theme.ink)
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
            .selectionDisabled()

            Label("Alle Notizbücher", systemImage: "books.vertical.fill")
                .badge(notebooks.count)
                .tag(SidebarItem.all)
            Section("Ordner") {
                OutlineGroup(rootFolders, children: \.subfolders) { folder in
                    Label { Text(folder.name) } icon: {
                        Image(systemName: "folder.fill").foregroundStyle(theme.accent.opacity(0.8))
                    }
                    .badge(folder.notebooks?.count ?? 0)
                    .tag(SidebarItem.folder(folder))
                    .contextMenu { folderMenu(folder) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.sidebar)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Einstellungen", systemImage: "gearshape") { showSettings = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Neuer Ordner", systemImage: "folder.badge.plus") {
                    startNameEdit(.newFolder(parent: nil))
                }
            }
        }
    }

    @ViewBuilder
    private func folderMenu(_ folder: Folder) -> some View {
        Button("Neuer Unterordner", systemImage: "folder.badge.plus") {
            startNameEdit(.newFolder(parent: folder))
        }
        Button("Umbenennen", systemImage: "pencil") {
            startNameEdit(.renameFolder(folder))
        }
        Menu("Verschieben", systemImage: "folder") {
            Button("Oberste Ebene") { move(folder, to: nil) }
            ForEach(allFolders.filter { !folder.contains($0) }) { target in
                Button(target.pathName) { move(folder, to: target) }
            }
        }
        Divider()
        Button("Löschen", systemImage: "trash", role: .destructive) {
            confirmDelete(.folder(folder))
        }
    }

    // MARK: Grid

    private var currentFolder: Folder? {
        if case .folder(let folder) = selection { return folder }
        return nil
    }

    private var visibleNotebooks: [Notebook] {
        guard let folder = currentFolder else { return notebooks }
        return notebooks.filter { $0.folder == folder }
    }

    private var grid: some View {
        ScrollView {
            header
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(visibleNotebooks) { notebook in
                    NavigationLink(value: notebook) {
                        NotebookCover(notebook: notebook)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu { notebookMenu(notebook) }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Backdrop())
        .overlay {
            if visibleNotebooks.isEmpty { emptyState }
        }
        .navigationTitle(currentFolder?.name ?? "Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Großer Titel steht im Inhalt (in der Schrift des Themas), oben bleibt es ruhig.
            ToolbarItem(placement: .principal) { Text("") }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            Button("Importieren", systemImage: "square.and.arrow.down") { showImporter = true }
            Button("Neues Notizbuch", systemImage: "plus") { showNewNotebook = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(currentFolder?.name ?? Theme.greeting(name: userName))
                    .font(theme.title(38))
                    .foregroundStyle(theme.ink)
                if currentFolder == nil {
                    Image(systemName: theme.motif)
                        .font(.system(size: 22))
                        .foregroundStyle(theme.accent)
                        .symbolEffect(.bounce, value: theme.id)
                }
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var subtitle: String {
        let n = visibleNotebooks.count
        let books = n == 1 ? "1 Notizbuch" : "\(n) Notizbücher"
        return currentFolder == nil ? "\(books) in deiner Bibliothek" : books
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: theme.motif)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(theme.accent.gradient, in: Circle())
                .shadow(color: theme.accent.opacity(0.4), radius: 12, y: 6)
            Text(currentFolder == nil ? "Noch keine Notizbücher" : "Dieser Ordner ist noch leer")
                .font(theme.title(22))
                .foregroundStyle(theme.ink)
            Text("Leg dein erstes Notizbuch an und fang einfach an zu schreiben.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryInk)
                .multilineTextAlignment(.center)
            Button {
                showNewNotebook = true
            } label: {
                Label("Neues Notizbuch", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(theme.accent, in: Capsule())
                    .foregroundStyle(Theme.onColor(theme.accentHex))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 6)
        }
        .padding(40)
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private func notebookMenu(_ notebook: Notebook) -> some View {
        Button("Umbenennen", systemImage: "pencil") {
            startNameEdit(.renameNotebook(notebook))
        }
        Menu("Verschieben", systemImage: "folder") {
            Button("Kein Ordner") { move(notebook, to: nil) }
            ForEach(allFolders) { folder in
                Button(folder.pathName) { move(notebook, to: folder) }
            }
        }
        Menu("Coverfarbe", systemImage: "paintpalette") {
            ForEach(theme.covers, id: \.hex) { cover in
                Button(cover.name) {
                    notebook.coverColorHex = cover.hex
                    save()
                }
            }
        }
        Menu("Exportieren", systemImage: "square.and.arrow.up") {
            ForEach(ExportFormat.allCases) { format in
                Button(format.title, systemImage: format.systemImage) { export(notebook, as: format) }
            }
        }
        Divider()
        Button("Löschen", systemImage: "trash", role: .destructive) {
            confirmDelete(.notebook(notebook))
        }
    }

    // MARK: Aktionen

    private func createNotebook(title: String, paper: PaperStyle, paperColor: PaperColor, color: String) {
        let notebook = Notebook(title: title, paperStyle: paper, paperColor: paperColor,
                                coverColorHex: color, folder: currentFolder)
        context.insert(notebook)
        notebook.addPage()
        save()
        path.append(notebook)
    }

    private func importFiles(_ urls: [URL]) {
        var imported: [Notebook] = []
        var errors: [String] = []
        for url in urls {
            do {
                imported.append(try NotebookImporter.importFile(at: url, into: context, folder: currentFolder))
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !errors.isEmpty { transferError = errors.joined(separator: "\n\n") }
        // Ein einzelnes Notizbuch direkt öffnen.
        if imported.count == 1, errors.isEmpty {
            path = NavigationPath()
            path.append(imported[0])
        }
    }

    private func export(_ notebook: Notebook, as format: ExportFormat) {
        save()
        do {
            shareItem = ShareItem(url: try NotebookExporter.export(notebook, as: format))
        } catch {
            transferError = error.localizedDescription
        }
    }

    private func move(_ notebook: Notebook, to folder: Folder?) {
        notebook.folder = folder
        save()
    }

    private func move(_ folder: Folder, to parent: Folder?) {
        guard parent.map({ !folder.contains($0) }) ?? true else { return }
        folder.parent = parent
        save()
    }

    private func startNameEdit(_ edit: NameEdit) {
        nameEdit = edit
        nameText = edit.initialText
        isEditingName = true
    }

    private func applyNameEdit() {
        let name = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let edit = nameEdit else { return }
        switch edit {
        case .newFolder(let parent):
            let folder = Folder(name: name, parent: parent)
            context.insert(folder)
            selection = .folder(folder)
        case .renameFolder(let folder):
            folder.name = name
        case .renameNotebook(let notebook):
            notebook.title = name
            notebook.touch()
        }
        save()
    }

    private func confirmDelete(_ target: DeleteTarget) {
        deleteTarget = target
        isDeleting = true
    }

    private func delete(_ target: DeleteTarget) {
        switch target {
        case .notebook(let notebook):
            context.delete(notebook)
        case .folder(let folder):
            // Notizbücher bleiben erhalten und wandern eine Ebene nach oben.
            for sub in folder.subtree {
                let contained = sub.notebooks ?? []
                for notebook in contained { notebook.folder = folder.parent }
                sub.notebooks = []
            }
            if case .folder(let selected) = selection, folder.contains(selected) {
                selection = .all
            }
            context.delete(folder)
        }
        save()
    }

    private func save() { AutoSaver.saveNow(context) }
}

// MARK: - Hilfstypen

private enum NameEdit {
    case newFolder(parent: Folder?)
    case renameFolder(Folder)
    case renameNotebook(Notebook)

    var title: String {
        switch self {
        case .newFolder(let parent): parent == nil ? "Neuer Ordner" : "Neuer Unterordner"
        case .renameFolder: "Ordner umbenennen"
        case .renameNotebook: "Notizbuch umbenennen"
        }
    }

    var initialText: String {
        switch self {
        case .newFolder: ""
        case .renameFolder(let folder): folder.name
        case .renameNotebook(let notebook): notebook.title
        }
    }
}

private enum DeleteTarget {
    case folder(Folder)
    case notebook(Notebook)

    var title: String {
        switch self {
        case .folder(let folder): "Ordner „\(folder.name)“ löschen?"
        case .notebook(let notebook): "„\(notebook.title)“ löschen?"
        }
    }

    var message: String {
        switch self {
        case .folder(let folder):
            "Die Notizbücher darin werden nach \(folder.parent.map { "„\($0.name)“" } ?? "„Alle Notizbücher“") verschoben."
        case .notebook:
            "Das Notizbuch und alle Seiten werden endgültig gelöscht."
        }
    }
}
