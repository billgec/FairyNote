import SwiftUI

/// Auswahl von Vorlage, Liniatur und Papierfarbe, mit kleinen Seitenvorschauen.
/// Wird beim Anlegen eines Notizbuchs und nachträglich im Notizbuch benutzt.
struct PaperPicker: View {
    @Environment(\.theme) private var theme
    @Binding var style: PaperStyle
    @Binding var color: PaperColor
    var showsTemplates = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsTemplates {
                section("Vorlagen") {
                    ForEach(NotebookTemplate.all) { template in
                        thumbnail(template.name, style: template.style, color: template.color,
                                  selected: style == template.style && color == template.color) {
                            style = template.style
                            color = template.color
                        }
                    }
                }
            }
            section("Liniatur") {
                ForEach(PaperStyle.allCases) { s in
                    thumbnail(s.title, style: s, color: color, selected: style == s) { style = s }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                label("Papierfarbe")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PaperColor.allCases) { c in swatch(c) }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
        }
        .animation(.snappy, value: style)
        .animation(.snappy, value: color)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.secondaryInk)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            label(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) { content() }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func thumbnail(_ title: String, style: PaperStyle, color: PaperColor,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                PaperBackground(style: style, color: color)
                    .frame(width: 72, height: 72 / (595.28 / 841.89)) // DIN A4
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(selected ? theme.accent : theme.hairline, lineWidth: selected ? 2.5 : 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(selected ? theme.ink : theme.secondaryInk)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func swatch(_ c: PaperColor) -> some View {
        let hexes = c.hexes(for: theme)
        let selected = color == c
        return Button { color = c } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color(hex: hexes.paper))
                    Circle().strokeBorder(Color(hex: hexes.line), lineWidth: 1)
                    if c == .theme {
                        Image(systemName: theme.motif)
                            .font(.caption)
                            .foregroundStyle(theme.accent)
                    }
                }
                .frame(width: 36, height: 36)
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? theme.accent : .clear, lineWidth: 2))
                Text(c.title)
                    .font(.caption2)
                    .foregroundStyle(selected ? theme.ink : theme.secondaryInk)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(c.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Nachträglich das Papier eines Notizbuchs ändern.
struct PaperSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Bindable var notebook: Notebook
    let onChange: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                PaperPicker(style: $notebook.paperStyle, color: $notebook.paperColor)
                    .padding(24)
                Text("Gilt für alle Seiten dieses Notizbuchs. Importierte PDF-Seiten behalten ihren Hintergrund.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryInk)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.background)
            .navigationTitle("Papier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .onChange(of: notebook.paperStyleRaw) { onChange() }
        .onChange(of: notebook.paperColorRaw) { onChange() }
        .presentationDetents([.medium, .large])
    }
}
