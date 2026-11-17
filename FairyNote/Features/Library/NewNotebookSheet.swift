import SwiftUI

/// Kurzer Dialog für ein neues Notizbuch: Name, Vorlage/Papier, Coverfarbe.
struct NewNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    let defaultTitle: String
    let onCreate: (String, PaperStyle, PaperColor, String) -> Void

    @State private var title = ""
    @State private var paper: PaperStyle = .lined
    @State private var paperColor: PaperColor = .theme
    @State private var chosenColor: String?

    private var color: String { chosenColor ?? theme.covers[0].hex }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(defaultTitle, text: $title)
                }
                Section("Papier") {
                    HStack(alignment: .top, spacing: 24) {
                        PaperBackground(style: paper, color: paperColor)
                            .aspectRatio(595.28 / 841.89, contentMode: .fit) // DIN A4
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(theme.hairline))
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                        PaperPicker(style: $paper, color: $paperColor)
                    }
                    .padding(.vertical, 8)
                }
                Section("Cover") {
                    HStack(alignment: .center, spacing: 24) {
                        CoverArt(title: title.isEmpty ? defaultTitle : title, hex: color, seed: Int(title.count))
                            .frame(width: 96)
                            .padding(.vertical, 8)
                            .animation(.snappy, value: color)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 10), count: 4), spacing: 10) {
                            ForEach(theme.covers, id: \.hex) { cover in
                                Button { chosenColor = cover.hex } label: {
                                    Circle()
                                        .fill(Color(hex: cover.hex))
                                        .frame(width: 34, height: 34)
                                        .padding(3)
                                        .overlay(Circle().strokeBorder(color == cover.hex ? theme.accent : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(cover.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Neues Notizbuch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(name.isEmpty ? defaultTitle : name, paper, paperColor, color)
                        dismiss()
                    }
                }
            }
        }
    }
}
