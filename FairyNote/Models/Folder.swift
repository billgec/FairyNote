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
}
