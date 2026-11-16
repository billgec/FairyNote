import SwiftUI
import UIKit

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

/// System-Teilen-Dialog für eine Datei (z. B. „In GoodNotes öffnen“, AirDrop, Dateien sichern).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
