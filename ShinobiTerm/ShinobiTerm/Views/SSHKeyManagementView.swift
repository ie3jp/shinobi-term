import SwiftUI

struct SSHKeyManagementView: View {
    @State private var keys: [SSHKeyInfo] = []
    @State private var showingGenerateSheet = false
    @State private var newKeyName = ""
    @State private var generatedKeyInfo: SSHKeyInfo?
    @State private var keyToDelete: SSHKeyInfo?
    @State private var copiedKeyId: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if keys.isEmpty {
                    emptyState
                } else {
                    keysSection
                }

                generateButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color("bgPage"))
        .navigationTitle("ssh_keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { loadKeys() }
        .alert("generate_key", isPresented: $showingGenerateSheet) {
            TextField("key_name", text: $newKeyName)
            Button("generate") { generateKey() }
            Button("cancel", role: .cancel) { newKeyName = "" }
        } message: {
            Text("enter a name for the new Ed25519 key pair")
        }
        .alert("delete_key?", isPresented: showDeleteAlert) {
            Button("delete", role: .destructive) { confirmDelete() }
            Button("cancel", role: .cancel) { keyToDelete = nil }
        } message: {
            if let key = keyToDelete {
                Text("'\(key.name)' will be permanently deleted. This cannot be undone.")
            }
        }
        .sheet(item: $generatedKeyInfo) { keyInfo in
            PublicKeySheet(keyInfo: keyInfo) {
                generatedKeyInfo = nil
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "key")
                .font(.system(size: 32))
                .foregroundStyle(Color("textTertiary"))
            Text("no ssh keys yet")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("textMuted"))
            Text("generate a key pair to use SSH key authentication")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color("textTertiary"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Keys List

    private var keysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("// keys")

            VStack(spacing: 0) {
                ForEach(Array(keys.enumerated()), id: \.element.id) { index, key in
                    keyRow(key)
                    if index < keys.count - 1 {
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
        }
    }

    private func keyRow(_ key: SSHKeyInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "key.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("greenPrimary"))
                Text(key.name)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color("textPrimary"))
                Spacer()

                // Copy public key
                Button {
                    copyPublicKey(key)
                } label: {
                    Image(systemName: copiedKeyId == key.id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(copiedKeyId == key.id ? Color("greenPrimary") : Color("textTertiary"))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // Delete key
                Button {
                    keyToDelete = key
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("redError"))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            Text(key.fingerprint)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color("textMuted"))
                .lineLimit(1)

            Text("ed25519 · \(key.createdAt.formatted(.dateTime.month().day().year()))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color("textTertiary"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            newKeyName = ""
            showingGenerateSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                Text("generate_key_pair")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Color("greenPrimary"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color("greenPrimary").opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("greenPrimary").opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadKeys() {
        keys = SSHKeyService.listKeys()
    }

    private func generateKey() {
        let name = newKeyName.isEmpty ? "shinobi-key" : newKeyName
        newKeyName = ""
        do {
            let keyInfo = try SSHKeyService.generateKeyPair(name: name)
            generatedKeyInfo = keyInfo
            loadKeys()
        } catch {
            // Generation failed silently — CryptoKit errors are rare
        }
    }

    private func copyPublicKey(_ key: SSHKeyInfo) {
        UIPasteboard.general.string = key.publicKey
        copiedKeyId = key.id
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedKeyId == key.id {
                copiedKeyId = nil
            }
        }
    }

    private func confirmDelete() {
        guard let key = keyToDelete else { return }
        try? SSHKeyService.deleteKey(keyId: key.id)
        keyToDelete = nil
        loadKeys()
    }

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { keyToDelete != nil },
            set: { if !$0 { keyToDelete = nil } }
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color("textTertiary"))
    }
}

// MARK: - Public Key Display Sheet

struct PublicKeySheet: View {
    let keyInfo: SSHKeyInfo
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color("greenPrimary"))
                    Text("key generated")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color("textPrimary"))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("public_key")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color("textTertiary"))
                    Text(keyInfo.publicKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color("textSecondary"))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("bgSurface"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("borderPrimary"), lineWidth: 1)
                        )
                }

                Text("add this public key to ~/.ssh/authorized_keys on your server")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color("textMuted"))
                    .multilineTextAlignment(.center)

                Button {
                    UIPasteboard.general.string = keyInfo.publicKey
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "copied!" : "copy_public_key")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color("greenPrimary"))
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding(20)
            .background(Color("bgPage"))
            .navigationTitle(keyInfo.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { onDismiss() }
                        .foregroundStyle(Color("greenPrimary"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
