import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var newDomain: String = ""
    @State private var showingAddError = false
    @State private var addErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Blocked Sites")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Add new domain section
            HStack {
                TextField("Enter domain (e.g., example.com)", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addDomain()
                    }

                Button(action: addDomain) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .disabled(newDomain.isEmpty)
            }
            .padding()

            Divider()

            // List of blocked sites
            if appSettings.blockedSites.isEmpty {
                VStack {
                    Spacer()
                    Text("No blocked sites")
                        .foregroundColor(.secondary)
                    Text("Add domains above to block them")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(appSettings.blockedSites, id: \.self) { domain in
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.secondary)
                            Text(domain)
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteDomains)
                }
            }
        }
        .frame(width: 500, height: 400)
        .alert("Invalid Domain", isPresented: $showingAddError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addErrorMessage)
        }
    }

    private func addDomain() {
        let trimmed = newDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Basic validation
        guard !trimmed.isEmpty else { return }

        // Check if domain is already in the list
        if appSettings.blockedSites.contains(trimmed) {
            addErrorMessage = "This domain is already in the blocked list."
            showingAddError = true
            return
        }

        // Basic domain validation (simple check)
        if !isValidDomain(trimmed) {
            addErrorMessage = "Please enter a valid domain name (e.g., example.com)"
            showingAddError = true
            return
        }

        // Add to blocked sites
        appSettings.blockedSites.append(trimmed)
        appSettings.blockedSites.sort()

        // Clear input
        newDomain = ""

        // If blocking is currently enabled, update the PAC file
        if appSettings.isBlockingEnabled {
            Task {
                try? await ProxyManager.shared.enableBlocking(domains: appSettings.blockedSites)
            }
        }
    }

    private func deleteDomains(at offsets: IndexSet) {
        appSettings.blockedSites.remove(atOffsets: offsets)

        // If blocking is currently enabled, update the PAC file
        if appSettings.isBlockingEnabled {
            Task {
                try? await ProxyManager.shared.enableBlocking(domains: appSettings.blockedSites)
            }
        }
    }

    private func isValidDomain(_ domain: String) -> Bool {
        // Simple domain validation
        let domainRegex = "^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$"
        let domainPredicate = NSPredicate(format: "SELF MATCHES %@", domainRegex)
        return domainPredicate.evaluate(with: domain)
    }
}
