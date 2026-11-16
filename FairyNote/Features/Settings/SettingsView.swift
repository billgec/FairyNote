import SwiftUI

/// Einstellungen: Thema wählen, Name für die Begrüßung.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @AppStorage(AppTheme.storageKey) private var themeID = AppTheme.standard.id
    @AppStorage(AppTheme.nameKey) private var userName = ""

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section("Design", symbol: "paintpalette.fill") {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(AppTheme.all) { option in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.35)) { themeID = option.id }
                                } label: {
                                    ThemeCard(option: option, isSelected: option.id == themeID)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }

                    section("Persönlich", symbol: "person.crop.circle.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Dein Name", text: $userName)
                                .textInputAutocapitalization(.words)
                                .padding(14)
                                .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.hairline))
                            Text("Für die Begrüßung in der Bibliothek: „\(Theme.greeting(name: userName))“")
                                .font(.footnote)
                                .foregroundStyle(theme.secondaryInk)
                        }
                    }

                    HStack(spacing: 6) {
                        Spacer()
                        Text("FairyNote · mit")
                        Image(systemName: "heart.fill").foregroundStyle(theme.accent)
                        Text("gemacht")
                        Spacer()
                    }
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryInk)
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Backdrop())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, symbol: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(theme.title(20))
                .foregroundStyle(theme.ink)
            content()
        }
    }
}

/// Vorschaukarte eines Themas mit drei Mini-Covern im jeweiligen Stil.
private struct ThemeCard: View {
    let option: AppTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    CoverArt(title: ["Bio", "Mathe", "Ideen"][i], hex: option.covers[i * 2].hex, seed: i * 3)
                        .frame(width: 52)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Color(hex: option.backgroundHex), in: RoundedRectangle(cornerRadius: 14))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(option.title(18))
                        .foregroundStyle(Color(hex: option.inkHex))
                    Text(option.tagline)
                        .font(.caption)
                        .foregroundStyle(Color(hex: option.secondaryHex))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? option.accent : Color(hex: option.secondaryHex).opacity(0.5))
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(Color(hex: option.surfaceHex), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(isSelected ? option.accent : Color(hex: option.hairlineHex), lineWidth: isSelected ? 2.5 : 1))
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.05), radius: isSelected ? 12 : 6, y: 4)
        .environment(\.theme, option)
    }
}
