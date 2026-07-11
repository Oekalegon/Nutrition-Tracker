import SwiftUI
import SwiftData

struct DiaryView: View {
    @Query(sort: \DiaryEntry.timestamp, order: .reverse) private var entries: [DiaryEntry]

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "book.pages",
                        description: Text("What you log will show up here.")
                    )
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.label ?? "Entry")
                                .font(.headline)
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Diary")
        }
    }
}

#Preview {
    DiaryView()
        .modelContainer(for: [Food.self, DiaryEntry.self], inMemory: true)
}
