import Foundation
import SwiftData

@Model
final class Folder {
    var name: String = ""
    var createdAt: Date = Date()
    var parent: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent) var children: [Folder]? = []
    @Relationship(deleteRule: .cascade, inverse: \Notebook.folder) var notebooks: [Notebook]? = []

    init(name: String, parent: Folder? = nil) {
        self.name = name
        self.parent = parent
    }

    /// Unterordner alphabetisch, `nil` wenn keine vorhanden (damit die Sidebar keinen leeren Pfeil zeigt).
    var subfolders: [Folder]? {
        let sorted = (children ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return sorted.isEmpty ? nil : sorted
    }

    /// Voller Pfad, z. B. "Uni / Mathe".
    var pathName: String {
        if let parent { return "\(parent.pathName) / \(name)" }
        return name
    }

    /// Ordner selbst und alle Unterordner (rekursiv).
    var subtree: [Folder] {
        [self] + (children ?? []).flatMap(\.subtree)
    }

    /// Ist `other` dieser Ordner oder liegt er darin?
    func contains(_ other: Folder) -> Bool {
        var current: Folder? = other
        while let folder = current {
            if folder == self { return true }
            current = folder.parent
        }
        return false
    }
}
