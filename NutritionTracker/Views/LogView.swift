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
                TextField("What did you eat?", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture { isInputFocused = false }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
            }
        }
    }
}

#Preview {
    LogView()
        .modelContainer(for: [Food.self, DiaryEntry.self], inMemory: true)
}
