import SwiftUI
import SwiftData

struct LogView: View {
    @State private var inputText: String = ""

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
                    .padding()
            }
            .navigationTitle("Log")
        }
    }
}

#Preview {
    LogView()
        .modelContainer(for: [Food.self, DiaryEntry.self], inMemory: true)
}
