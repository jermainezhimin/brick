import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text("Brick")
                .font(.headline)
                .padding(.bottom, 4)

            // Site Blocking Toggle
            Toggle(isOn: $appSettings.isBlockingEnabled) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(appSettings.isBlockingEnabled ? .blue : .gray)
                    Text("Block Websites")
                }
            }
            .toggleStyle(.switch)

            // Grayscale Toggle
            Toggle(isOn: $appSettings.isGrayscaleEnabled) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(appSettings.isGrayscaleEnabled ? .blue : .gray)
                    Text("Grayscale Mode")
                }
            }
            .toggleStyle(.switch)

            Divider()

            // Configure Sites Button
            Button(action: {
                appSettings.showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Configure Sites...")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)

            Divider()

            // Quit Button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit Brick")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding()
        .frame(width: 250)
        .sheet(isPresented: $appSettings.showingSettings) {
            SettingsView()
                .environmentObject(appSettings)
        }
        .alert("Error", isPresented: .constant(appSettings.errorMessage != nil)) {
            Button("OK") {
                appSettings.errorMessage = nil
            }
        } message: {
            if let errorMessage = appSettings.errorMessage {
                Text(errorMessage)
            }
        }
    }
}
