import SwiftUI

/// Kurzer Dialog für ein neues Notizbuch: Name, Papier, Coverfarbe.
struct NewNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    let defaultTitle: String
    let onCreate: (String, PaperStyle, String) -> Void

    @State private var title = ""
    @State private var paper: PaperStyle = .lined
    @State private var chosenColor: String?

    private var color: String { chosenColor ?? theme.covers[0].hex }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(defaultTitle, text: $title)
                }
                Section("Papier") {
                    Picker("Papier", selection: $paper) {
                        ForEach(PaperStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    PaperBackground(style: paper)
                        .aspectRatio(595.28 / 841.89, contentMode: .fit) // DIN A4
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().strokeBorder(.quaternary))
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
                        onCreate(name.isEmpty ? defaultTitle : name, paper, color)
                        dismiss()
                    }
                }
            }
        }
    }
}
