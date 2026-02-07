import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]

    private var settings: AppSettings {
        if let existing = allSettings.first {
            return existing
        }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Appearance
                appearanceSection

                // Terminal
                terminalSection

                // SSH Keys
                sshKeysSection

                // About
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color("bgPage"))
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("// appearance")

            VStack(spacing: 0) {
                NavigationLink {
                    FontPickerView(
                        selectedFont: Binding(
                            get: { settings.fontName },
                            set: { settings.fontName = $0 }
                        )
                    )
                } label: {
                    settingRow(label: "font", value: settings.fontName)
                }

                settingDivider

                HStack {
                    Text("font_size")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color("textPrimary"))
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            if settings.fontSize > 8 { settings.fontSize -= 1 }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 12))
                                .foregroundStyle(Color("textSecondary"))
                                .frame(width: 28, height: 28)
                                .background(Color("bgElevated"))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(settings.fontSize))px")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color("textSecondary"))
                            .monospacedDigit()
                            .frame(width: 40)

                        Button {
                            if settings.fontSize < 32 { settings.fontSize += 1 }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                                .foregroundStyle(Color("textSecondary"))
                                .frame(width: 28, height: 28)
                                .background(Color("bgElevated"))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("textTertiary"))
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)

                settingDivider

                settingRow(label: "color_scheme", value: settings.colorScheme.lowercased())
            }
            .background(Color("bgSurface"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
        }
    }

    // MARK: - Terminal

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("// terminal")

            VStack(spacing: 0) {
                settingRow(label: "scrollback_buffer", value: settings.scrollbackLines.formatted())

                settingDivider

                HStack {
                    Text("bell")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color("textPrimary"))
                    Spacer()
                    Text(settings.hapticFeedback ? "vibrate" : "off")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color("textSecondary"))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("textTertiary"))
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
            }
            .background(Color("bgSurface"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
        }
    }

    // MARK: - SSH Keys

    private var sshKeysSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("// ssh_keys")

            VStack(spacing: 0) {
                settingRow(label: "manage_keys", value: "")

                settingDivider

                settingRow(label: "generate_key_pair", value: "")
            }
            .background(Color("bgSurface"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("// about")

            VStack(spacing: 0) {
                settingRow(label: "version", value: "\(Bundle.main.shortVersion)")

                settingDivider

                settingRow(label: "github", value: "open_source")

                settingDivider

                settingRow(label: "license", value: "MIT")
            }
            .background(Color("bgSurface"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
        }
    }

    // MARK: - Components

    private func settingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color("textPrimary"))
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color("textSecondary"))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color("textTertiary"))
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private var settingDivider: some View {
        Rectangle()
            .fill(Color("borderPrimary"))
            .frame(height: 1)
            .padding(.leading, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color("textTertiary"))
            .padding(.bottom, 2)
    }
}

// MARK: - Font Picker

struct FontPickerView: View {
    @Binding var selectedFont: String
    @Environment(\.dismiss) private var dismiss

    private let fonts = [
        "Menlo", "Courier New", "SF Mono",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(fonts, id: \.self) { font in
                    Button {
                        selectedFont = font
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(font)
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color("textPrimary"))
                                Text("Hello World 0123456789")
                                    .font(.custom(font, size: 14))
                                    .foregroundStyle(Color("textSecondary"))
                            }
                            Spacer()
                            if selectedFont == font {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color("greenPrimary"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if font != fonts.last {
                        Rectangle()
                            .fill(Color("borderPrimary"))
                            .frame(height: 1)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color("bgSurface"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
            .padding(16)
        }
        .background(Color("bgPage"))
        .navigationTitle("font")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Acknowledgements

struct AcknowledgementsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                acknowledgementRow("SwiftTerm", author: "Miguel de Icaza", license: "MIT")
                settingDivider
                acknowledgementRow("Citadel", author: "Orlandos", license: "MIT")
                settingDivider
                acknowledgementRow("SwiftNIO SSH", author: "Apple Inc.", license: "Apache 2.0")
            }
            .background(Color("bgSurface"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
            .padding(16)
        }
        .background(Color("bgPage"))
        .navigationTitle("acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func acknowledgementRow(_ name: String, author: String, license: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color("textPrimary"))
            Text("by \(author) · \(license)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color("textMuted"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var settingDivider: some View {
        Rectangle()
            .fill(Color("borderPrimary"))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
