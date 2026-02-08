import CryptoKit
import SwiftData
import SwiftUI

struct ConnectionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingProfile: ConnectionProfile?

    @State private var name = ""
    @State private var hostname = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod: AuthMethod = .password
    @State private var password = ""
    @State private var sshKey = ""
    @State private var selectedKeyId: String?
    @State private var availableKeys: [SSHKeyInfo] = []
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic section
                    basicSection

                    // Authentication section
                    authSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }

            // Bottom buttons
            VStack(spacing: 12) {
                // Save button
                Button {
                    save()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                        Text("save_connection")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color("greenPrimary"))
                    .cornerRadius(10)
                }
                .disabled(name.isEmpty || hostname.isEmpty || username.isEmpty)
                .opacity(name.isEmpty || hostname.isEmpty || username.isEmpty ? 0.5 : 1)

                // Test button
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 8) {
                        if isTesting {
                            ProgressView()
                                .tint(Color("textSecondary"))
                        } else {
                            Image(systemName: "bolt")
                                .font(.system(size: 16))
                        }
                        Text("test_connection")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(Color("textSecondary"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color("bgSurface"))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("borderPrimary"), lineWidth: 1)
                    )
                }
                .disabled(isTesting || hostname.isEmpty || username.isEmpty)

                // Test result
                if let result = testResult {
                    switch result {
                    case .success:
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("connection successful")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .foregroundStyle(Color("greenPrimary"))
                    case .failure(let message):
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text(message)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color("redError"))
                    }
                }
            }
            .padding(16)
        }
        .background(Color("bgPage"))
        .navigationTitle(editingProfile != nil ? "edit_connection" : "add_connection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("greenPrimary"))
                    .disabled(name.isEmpty || hostname.isEmpty || username.isEmpty)
            }
        }
        .onAppear {
            availableKeys = SSHKeyService.listKeys()
            if let profile = editingProfile {
                name = profile.name
                hostname = profile.hostname
                port = String(profile.port)
                username = profile.username
                authMethod = profile.authMethod
                selectedKeyId = profile.sshKeyId
                let profileId = profile.profileId
                password = (try? KeychainService.loadPassword(for: profileId)) ?? ""
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Basic Section

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("// basic")

            inputField(label: "name", placeholder: "my_server", text: $name)
            inputField(label: "hostname", placeholder: "192.168.1.100", text: $hostname,
                       autocapitalize: false)

            // Port + Username side by side
            HStack(spacing: 12) {
                inputField(label: "port", placeholder: "22", text: $port,
                           keyboardType: .numberPad)
                inputField(label: "username", placeholder: "root", text: $username,
                           autocapitalize: false)
            }
        }
    }

    // MARK: - Auth Section

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("// authentication")

            // Segmented control
            HStack(spacing: 0) {
                authTab("password", isSelected: authMethod == .password) {
                    authMethod = .password
                }
                authTab("ssh_key", isSelected: authMethod == .sshKey) {
                    authMethod = .sshKey
                }
            }
            .background(Color("bgSurface"))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )

            if authMethod == .password {
                inputField(label: "password", placeholder: "••••••••", text: $password,
                           isSecure: true, autocapitalize: false)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ssh_key")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))

                    if availableKeys.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.yellow)
                            Text("no keys found. generate one in Settings > SSH Keys.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color("textMuted"))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("bgInput"))
                        .cornerRadius(8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(availableKeys) { key in
                                Button {
                                    selectedKeyId = key.id
                                } label: {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color("greenPrimary"))
                                        Text(key.name)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(Color("textPrimary"))
                                        Spacer()
                                        if selectedKeyId == key.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color("greenPrimary"))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 44)
                                }
                                .buttonStyle(.plain)

                                if key.id != availableKeys.last?.id {
                                    Rectangle()
                                        .fill(Color("borderPrimary"))
                                        .frame(height: 1)
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .background(Color("bgInput"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("borderPrimary"), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Components

    private func authTab(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isSelected ? Color("greenPrimary") : Color("textMuted"))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isSelected ? Color("greenPrimary").opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        autocapitalize: Bool = true,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color("textMuted"))

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                        .keyboardType(keyboardType)
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(Color("textPrimary"))
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color("bgInput"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color("textTertiary"))
    }

    // MARK: - Actions

    private func save() {
        let portNumber = Int(port) ?? 22

        if let profile = editingProfile {
            profile.name = name
            profile.hostname = hostname
            profile.port = portNumber
            profile.username = username
            profile.authMethod = authMethod
            profile.sshKeyId = authMethod == .sshKey ? selectedKeyId : nil
            saveCredentials(for: profile.profileId)
        } else {
            let profile = ConnectionProfile(
                name: name,
                hostname: hostname,
                port: portNumber,
                username: username,
                authMethod: authMethod
            )
            profile.sshKeyId = authMethod == .sshKey ? selectedKeyId : nil
            modelContext.insert(profile)
            try? modelContext.save()
            saveCredentials(for: profile.profileId)
        }

        dismiss()
    }

    private func saveCredentials(for profileId: String) {
        if authMethod == .password {
            try? KeychainService.savePassword(password, for: profileId)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let session = SSHSession()
            switch authMethod {
            case .password:
                await session.connect(
                    hostname: hostname,
                    port: Int(port) ?? 22,
                    username: username,
                    password: password
                )
            case .sshKey:
                let privateKey: Curve25519.Signing.PrivateKey? = {
                    guard let keyId = selectedKeyId else { return nil }
                    return try? SSHKeyService.loadPrivateKey(keyId: keyId)
                }()
                await session.connect(
                    hostname: hostname,
                    port: Int(port) ?? 22,
                    username: username,
                    authMethod: .sshKey,
                    privateKey: privateKey
                )
            }

            await MainActor.run {
                isTesting = false
                if session.state == .connected {
                    testResult = .success
                    session.disconnect()
                } else if case .error(let message) = session.state {
                    testResult = .failure(message)
                } else {
                    testResult = .failure("Connection failed")
                }
            }
        }
    }
}
