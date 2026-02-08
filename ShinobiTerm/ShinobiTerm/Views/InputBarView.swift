import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("command or message...", text: $text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color("textPrimary"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isFocused)
                .onSubmit { onSend() }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        text.isEmpty ? Color("textTertiary") : Color("greenPrimary")
                    )
            }
            .disabled(text.isEmpty)
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
