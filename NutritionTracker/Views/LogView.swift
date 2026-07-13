import SwiftUI
import SwiftData

struct LogView: View {
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                ContentUnavailableView(
                    "Log something",
                    systemImage: "plus.circle",
                    description: Text("Type what you ate, e.g. \u{201C}one banana\u{201D}.")
                )
                Spacer()
                HStack {
                    TextField("What did you eat?", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)

                    if isInputFocused {
                        Button("Done") { isInputFocused = false }
                    }
                }
                .padding()
            }
            // Screen-wide dismiss-on-tap — safe while this VStack only holds the placeholder
            // and text field. Once NUTR-20 replaces the placeholder with real tappable content
            // (search results, suggestion chips), re-verify this doesn't race child gestures.
            .contentShape(Rectangle())
            .onTapGesture { isInputFocused = false }
            .navigationTitle("Log")
        }
    }
}

#Preview {
    LogView()
        .modelContainer(for: [Food.self, DiaryEntry.self], inMemory: true)
}
