import SwiftUI

/// Kurzer Dialog für ein neues Notizbuch: Name, Papier, Coverfarbe.
struct NewNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss
    let defaultTitle: String
    let onCreate: (String, PaperStyle, String) -> Void

    @State private var title = ""
    @State private var paper: PaperStyle = .lined
    @State private var color = Notebook.coverColors[0]

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
                        .aspectRatio(PageView.aspectRatio, contentMode: .fit)
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().strokeBorder(.quaternary))
                }
                Section("Cover") {
                    HStack(spacing: 14) {
                        ForEach(Notebook.coverColors, id: \.self) { hex in
                            Button { color = hex } label: {
                                Circle()
                                    .fill(Color(hex: hex).gradient)
                                    .frame(width: 34, height: 34)
                                    .padding(3)
                                    .overlay(Circle().strokeBorder(color == hex ? Color.accentColor : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
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
