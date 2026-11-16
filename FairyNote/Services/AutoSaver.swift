import Foundation
import SwiftData
import os

/// Speichert Änderungen kurz nach dem letzten Strich und sofort, wenn die App in den Hintergrund geht.
@MainActor
enum AutoSaver {
    private static var pending: Task<Void, Never>?
    private static let log = Logger(subsystem: "com.billgec.FairyNote", category: "AutoSaver")

    /// Speichert 1 Sekunde nach der letzten Änderung (weitere Änderungen verschieben den Zeitpunkt).
    static func schedule(_ context: ModelContext) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            saveNow(context)
        }
    }

    static func saveNow(_ context: ModelContext) {
        pending?.cancel()
        pending = nil
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            log.error("Speichern fehlgeschlagen: \(error.localizedDescription)")
        }
    }
}
