import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Targets") {
                    Text("Daily nutrition targets")
                    Text("Weight goal")
                }
                Section("Apple Health") {
                    Text("Import weight")
                    Text("Export nutrition")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
