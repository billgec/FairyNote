import Foundation
import SwiftData

@Model
final class Page {
    var index: Int = 0
    @Attribute(.externalStorage) var drawingData: Data?
    var recognizedText: String?
    var notebook: Notebook?

    init(index: Int) {
        self.index = index
    }
}
