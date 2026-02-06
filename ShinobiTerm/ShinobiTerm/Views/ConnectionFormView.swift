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
    @State private var showPassword = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    LabeledContent("Name") {
                        TextField("My Server", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Hostname") {
                        TextField("192.168.1.10", text: $hostname)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Port") {
                        TextField("22", text: $port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    LabeledContent("Username") {
                        TextField("user", text: $username)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Authentication") {
                    Picker("Method", selection: $authMethod) {
                        Text("Password").tag(AuthMethod.password)
                        Text("SSH Key").tag(AuthMethod.sshKey)
                    }

                    if authMethod == .password {
                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Password", text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        TextEditor(text: $sshKey)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 120)
                            .overlay {
                                if sshKey.isEmpty {
                                    Text("Paste your SSH private key here")
                                        .foregroundStyle(.tertiary)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Image(systemName: "bolt")
                            Text("Test Connection")
                            Spacer()
                        }
                        .foregroundStyle(.indigo)
                    }
                    .disabled(isTesting || hostname.isEmpty || username.isEmpty)

                    if let result = testResult {
                        switch result {
                        case .success:
                            Label("Connection successful", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(editingProfile == nil ? "New Connection" : "Edit Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || hostname.isEmpty || username.isEmpty)
                }
            }
            .onAppear {
                if let profile = editingProfile {
                    name = profile.name
                    hostname = profile.hostname
                    port = String(profile.port)
                    username = profile.username
                    authMethod = profile.authMethod
                    let profileId = profile.persistentModelID.hashValue.description
                    password = (try? KeychainService.loadPassword(for: profileId)) ?? ""
                    sshKey = (try? KeychainService.loadSSHKey(for: profileId)) ?? ""
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let portNumber = Int(port) ?? 22

        if let profile = editingProfile {
            profile.name = name
            profile.hostname = hostname
            profile.port = portNumber
            profile.username = username
            profile.authMethod = authMethod
            saveCredentials(for: profile.persistentModelID.hashValue.description)
        } else {
            let profile = ConnectionProfile(
                name: name,
                hostname: hostname,
                port: portNumber,
                username: username,
                authMethod: authMethod
            )
            modelContext.insert(profile)
            // Save credentials after insert so we have a persistent ID
            try? modelContext.save()
            saveCredentials(for: profile.persistentModelID.hashValue.description)
        }

        dismiss()
    }

    private func saveCredentials(for profileId: String) {
        switch authMethod {
        case .password:
            try? KeychainService.savePassword(password, for: profileId)
        case .sshKey:
            try? KeychainService.saveSSHKey(sshKey, for: profileId)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let session = SSHSession()
            await session.connect(
                hostname: hostname,
                port: Int(port) ?? 22,
                username: username,
                password: password
            )

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
