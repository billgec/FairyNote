import SwiftUI

/// Schlichte Werkzeugleiste über den Seiten: Werkzeug, Farbe, Stärke, Rückgängig.
struct ToolBarView: View {
    @Environment(\.theme) private var theme
    @Bindable var tools: ToolState

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(ToolState.Kind.allCases) { kind in
                    ToolButton(symbol: kind.symbol, title: kind.title, isSelected: tools.kind == kind) {
                        tools.kind = kind
                    }
                }
            }

            if tools.kind == .eraser {
                Divider().frame(height: 24)
                Picker("Radierer", selection: $tools.eraserMode) {
                    Text("Strich").tag(ToolState.EraserMode.stroke)
                    Text("Pixel").tag(ToolState.EraserMode.pixel)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if tools.kind == .pen || tools.kind == .marker {
                Divider().frame(height: 24)
                HStack(spacing: 10) {
                    ForEach(tools.colors, id: \.self) { hex in
                        ColorDot(hex: hex, isSelected: tools.colorHex == hex) { tools.colorHex = hex }
                    }
                    ColorPicker("Eigene Farbe", selection: customColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 28, height: 28)
                }
            }

            if !tools.widths.isEmpty {
                Divider().frame(height: 24)
                HStack(spacing: 4) {
                    ForEach(Array(tools.widths.enumerated()), id: \.offset) { i, width in
                        WidthButton(level: i, isSelected: tools.width == width) { tools.width = width }
                    }
                }
            }

            Spacer(minLength: 0)

            ToolButton(symbol: "arrow.uturn.backward", title: "Rückgängig", isSelected: false, action: tools.undo)
            ToolButton(symbol: "arrow.uturn.forward", title: "Wiederholen", isSelected: false, action: tools.redo)
            Divider().frame(height: 24)
            ToolButton(symbol: tools.fingerDrawing ? "hand.draw.fill" : "hand.draw",
                       title: tools.fingerDrawing ? "Finger zeichnet" : "Nur Pencil zeichnet",
                       isSelected: tools.fingerDrawing) {
                tools.fingerDrawing.toggle()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        // Schwebende Leiste mit weichem Schatten statt einer flachen Linie.
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.hairline))
        .shadow(color: .black.opacity(theme.scheme == .dark ? 0.4 : 0.08), radius: 14, y: 6)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .animation(.snappy(duration: 0.2), value: tools.kind)
    }

    /// Eigene Farbe aus dem System-Farbwähler, gespeichert als Hex.
    private var customColor: Binding<Color> {
        Binding(
            get: { Color(hex: tools.colorHex) },
            set: { tools.colorHex = UIColor($0).hexString }
        )
    }
}

private struct ToolButton: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 40, height: 36)
                .background(isSelected ? theme.accent.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(isSelected ? theme.accent : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}

private struct ColorDot: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 1))
                .padding(3)
                .overlay(Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Farbe \(hex)")
    }
}

private struct WidthButton: View {
    @Environment(\.theme) private var theme
    let level: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .frame(width: 18, height: CGFloat(2 + level * 3))
                .frame(width: 36, height: 36)
                .background(isSelected ? theme.accent.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(isSelected ? theme.accent : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stärke \(level + 1)")
    }
}
