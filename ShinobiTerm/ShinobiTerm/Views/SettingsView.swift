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
        NavigationStack {
            List {
                Section("Appearance") {
                    NavigationLink {
                        FontPickerView(
                            selectedFont: Binding(
                                get: { settings.fontName },
                                set: { settings.fontName = $0 }
                            )
                        )
                    } label: {
                        LabeledContent("Font", value: settings.fontName)
                    }

                    HStack {
                        Text("Font Size")
                        Spacer()
                        Button {
                            if settings.fontSize > 8 {
                                settings.fontSize -= 1
                            }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 28, height: 28)
                                .background(Color(white: 0.15))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(settings.fontSize))")
                            .monospacedDigit()
                            .frame(width: 30)

                        Button {
                            if settings.fontSize < 32 {
                                settings.fontSize += 1
                            }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 28, height: 28)
                                .background(Color(white: 0.15))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    LabeledContent("Color Scheme", value: settings.colorScheme)
                }

                Section("Terminal") {
                    LabeledContent("Scrollback Lines") {
                        Text("\(settings.scrollbackLines.formatted())")
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Bell Sound", isOn: Binding(
                        get: { settings.bellSound },
                        set: { settings.bellSound = $0 }
                    ))

                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { settings.hapticFeedback },
                        set: { settings.hapticFeedback = $0 }
                    ))
                }

                Section("About") {
                    LabeledContent("Version") {
                        Text("\(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Acknowledgements") {
                        AcknowledgementsView()
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .preferredColorScheme(.dark)
    }
}

struct FontPickerView: View {
    @Binding var selectedFont: String
    @Environment(\.dismiss) private var dismiss

    private let fonts = [
        "Menlo", "Courier New", "SF Mono",
    ]

    var body: some View {
        List {
            ForEach(fonts, id: \.self) { font in
                Button {
                    selectedFont = font
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(font)
                                .font(.custom(font, size: 16))
                            Text("Hello こんにちは 世界 🌍")
                                .font(.custom(font, size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedFont == font {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AcknowledgementsView: View {
    var body: some View {
        List {
            acknowledgementRow("SwiftTerm", author: "Miguel de Icaza", license: "MIT")
            acknowledgementRow("Citadel", author: "Orlandos", license: "MIT")
            acknowledgementRow("SwiftNIO SSH", author: "Apple Inc.", license: "Apache 2.0")
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func acknowledgementRow(_ name: String, author: String, license: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .fontWeight(.medium)
            Text("by \(author) · \(license)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
