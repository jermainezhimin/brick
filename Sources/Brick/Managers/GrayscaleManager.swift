import Foundation
import CoreGraphics

@MainActor
class GrayscaleManager {
    static let shared = GrayscaleManager()

    private var originalGammas: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]
    private var displayReconfigCallback: CGDisplayReconfigurationCallBack?

    private init() {
        setupDisplayReconfigurationCallback()
    }

    func enableGrayscale() {
        let displays = getActiveDisplays()

        for displayID in displays {
            // Skip if we already have gamma for this display
            if originalGammas[displayID] != nil {
                continue
            }

            // Get the capacity for gamma tables
            var capacity: UInt32 = 0
            let result = CGGetDisplayTransferByTable(displayID, 0, nil, nil, nil, &capacity)

            guard result == .success, capacity > 0 else {
                print("Warning: Could not get gamma capacity for display \(displayID)")
                continue
            }

            // Allocate arrays for gamma tables
            var redTable = [CGGammaValue](repeating: 0, count: Int(capacity))
            var greenTable = [CGGammaValue](repeating: 0, count: Int(capacity))
            var blueTable = [CGGammaValue](repeating: 0, count: Int(capacity))

            // Get the current gamma tables
            let getResult = CGGetDisplayTransferByTable(
                displayID,
                capacity,
                &redTable,
                &greenTable,
                &blueTable,
                &capacity
            )

            guard getResult == .success else {
                print("Warning: Could not get gamma tables for display \(displayID)")
                continue
            }

            // Save original gamma tables
            originalGammas[displayID] = (red: redTable, green: greenTable, blue: blueTable)

            // Create grayscale gamma using luminance formula
            // Gray = 0.299*R + 0.587*G + 0.114*B
            var grayTable = [CGGammaValue](repeating: 0, count: Int(capacity))
            for i in 0..<Int(capacity) {
                let gray = 0.299 * redTable[i] + 0.587 * greenTable[i] + 0.114 * blueTable[i]
                grayTable[i] = gray
            }

            // Apply grayscale to all channels
            let setResult = CGSetDisplayTransferByTable(
                displayID,
                capacity,
                grayTable,
                grayTable,
                grayTable
            )

            if setResult != .success {
                print("Warning: Could not set gamma tables for display \(displayID)")
                originalGammas.removeValue(forKey: displayID)
            }
        }
    }

    func disableGrayscale() {
        // Restore original gamma tables
        for (displayID, gamma) in originalGammas {
            let capacity = UInt32(gamma.red.count)
            var redCopy = gamma.red
            var greenCopy = gamma.green
            var blueCopy = gamma.blue

            let result = CGSetDisplayTransferByTable(
                displayID,
                capacity,
                &redCopy,
                &greenCopy,
                &blueCopy
            )

            if result != .success {
                print("Warning: Could not restore gamma tables for display \(displayID)")
            }
        }

        originalGammas.removeAll()
    }

    private func getActiveDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)

        guard result == .success, displayCount > 0 else {
            return []
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        result = CGGetActiveDisplayList(displayCount, &displays, &displayCount)

        guard result == .success else {
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }

    private func setupDisplayReconfigurationCallback() {
        // Register callback for display configuration changes
        let callback: CGDisplayReconfigurationCallBack = { _, _, _ in
            // Re-apply grayscale when display configuration changes
            Task { @MainActor in
                if UserDefaults.standard.bool(forKey: "isGrayscaleEnabled") {
                    GrayscaleManager.shared.enableGrayscale()
                }
            }
        }

        CGDisplayRegisterReconfigurationCallback(callback, nil)
    }
}
