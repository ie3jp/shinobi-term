import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("command or message...", text: $text, axis: .vertical)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color("textPrimary"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isFocused)
                .lineLimit(1...3)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(hasContent ? Color("greenPrimary") : Color("textTertiary"))
            }
            .disabled(!hasContent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color("bgSurface"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color("borderPrimary"))
                .frame(height: 1)
        }
    }
}
