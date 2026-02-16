import Foundation
import SwiftUI

@MainActor
class AppSettings: ObservableObject {
    @Published var isGrayscaleEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isGrayscaleEnabled, forKey: "isGrayscaleEnabled")
            if isGrayscaleEnabled {
                GrayscaleManager.shared.enableGrayscale()
            } else {
                GrayscaleManager.shared.disableGrayscale()
            }
        }
    }

    @Published var isBlockingEnabled: Bool {
        didSet {
            let previousValue = !isBlockingEnabled
            UserDefaults.standard.set(isBlockingEnabled, forKey: "isBlockingEnabled")
            Task {
                do {
                    if isBlockingEnabled {
                        try await ProxyManager.shared.enableBlocking(domains: blockedSites)
                    } else {
                        try await ProxyManager.shared.disableBlocking()
                    }
                } catch {
                    // Revert the toggle on error
                    await MainActor.run {
                        self.isBlockingEnabled = previousValue
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    @Published var blockedSites: [String] {
        didSet {
            UserDefaults.standard.set(blockedSites, forKey: "blockedSites")
        }
    }

    @Published var showingSettings = false
    @Published var errorMessage: String?

    init() {
        // Load saved settings
        self.isGrayscaleEnabled = UserDefaults.standard.bool(forKey: "isGrayscaleEnabled")
        self.isBlockingEnabled = UserDefaults.standard.bool(forKey: "isBlockingEnabled")

        // Load blocked sites or use defaults
        if let saved = UserDefaults.standard.array(forKey: "blockedSites") as? [String], !saved.isEmpty {
            self.blockedSites = saved
        } else {
            self.blockedSites = AppSettings.defaultBlockedSites
        }

        // Re-apply grayscale if it was enabled
        if isGrayscaleEnabled {
            GrayscaleManager.shared.enableGrayscale()
        }

        // Re-apply blocking if it was enabled
        if isBlockingEnabled {
            Task {
                do {
                    try await ProxyManager.shared.enableBlocking(domains: blockedSites)
                } catch {
                    await MainActor.run {
                        self.isBlockingEnabled = false
                        print("Failed to re-enable blocking on startup: \(error.localizedDescription)")
                    }
                }
            }
        }

        // Register for wake notifications to re-apply grayscale
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isGrayscaleEnabled {
                    GrayscaleManager.shared.enableGrayscale()
                }
            }
        }
    }

    static let defaultBlockedSites = [
        "facebook.com",
        "twitter.com",
        "x.com",
        "instagram.com",
        "reddit.com",
        "youtube.com",
        "tiktok.com",
        "netflix.com",
        "twitch.tv"
    ]
}
