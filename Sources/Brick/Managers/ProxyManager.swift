import Foundation
import SystemConfiguration

@MainActor
class ProxyManager {
    static let shared = ProxyManager()

    private init() {}

    func enableBlocking(domains: [String]) async throws {
        // Generate PAC file content
        let pacContent = generatePAC(blockedDomains: domains)

        // Save PAC file to app support directory
        let pacURL = try savePACFile(content: pacContent)

        // Set system proxy configuration
        try await setSystemProxy(pacURL: pacURL)
    }

    func disableBlocking() async throws {
        // Remove PAC configuration
        try await removeSystemProxy()
    }

    private func generatePAC(blockedDomains: [String]) -> String {
        // Create JavaScript array of blocked domains
        let domainList = blockedDomains.map { "'\($0)'" }.joined(separator: ", ")

        return """
        function FindProxyForURL(url, host) {
            var blocked = [\(domainList)];

            // Check if host matches any blocked domain
            for (var i = 0; i < blocked.length; i++) {
                if (dnsDomainIs(host, blocked[i]) || host === blocked[i]) {
                    // Redirect to non-existent proxy (black hole)
                    return "PROXY 127.0.0.1:1";
                }
            }

            // Allow direct connection for all other sites
            return "DIRECT";
        }
        """
    }

    private func savePACFile(content: String) throws -> URL {
        // Get application support directory
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let brickDirectory = appSupportURL.appendingPathComponent("Brick", isDirectory: true)

        // Create Brick directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: brickDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Write PAC file
        let pacURL = brickDirectory.appendingPathComponent("proxy.pac")
        try content.write(to: pacURL, atomically: true, encoding: .utf8)

        return pacURL
    }

    private func setSystemProxy(pacURL: URL) async throws {
        // Request authorization from user
        let authorized = try await AuthManager.shared.requestAuthorization()

        guard authorized else {
            throw ProxyError.authorizationDenied
        }

        // Get authorization reference
        guard let authRef = AuthManager.shared.getAuthorizationRef() else {
            throw ProxyError.authorizationFailed
        }

        // Create preferences with authorization
        guard let prefs = SCPreferencesCreateWithAuthorization(
            nil,
            "com.brick.app" as CFString,
            nil,
            authRef
        ) else {
            throw ProxyError.preferencesCreationFailed
        }

        // Lock preferences for modification
        guard SCPreferencesLock(prefs, true) else {
            throw ProxyError.lockFailed
        }

        defer {
            SCPreferencesUnlock(prefs)
        }

        // Get network services
        guard let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else {
            throw ProxyError.noNetworkServices
        }

        // Configure proxy for each active network service
        for service in services {
            guard SCNetworkServiceGetEnabled(service) else {
                continue
            }

            guard let protocolSet = SCNetworkServiceCopyProtocols(service) as? [SCNetworkProtocol] else {
                continue
            }

            for networkProtocol in protocolSet {
                let type = SCNetworkProtocolGetProtocolType(networkProtocol)
                if type == kSCNetworkProtocolTypeIPv4 || type == kSCNetworkProtocolTypeIPv6 {
                    // Get proxies configuration
                    if let proxies = SCNetworkProtocolGetConfiguration(networkProtocol) as? [String: Any] {
                        var newProxies = proxies

                        // Enable PAC
                        newProxies[kCFNetworkProxiesProxyAutoConfigEnable as String] = 1
                        newProxies[kCFNetworkProxiesProxyAutoConfigURLString as String] = pacURL.absoluteString

                        // Set the new configuration
                        SCNetworkProtocolSetConfiguration(networkProtocol, newProxies as CFDictionary)
                    }
                }
            }
        }

        // Commit changes
        guard SCPreferencesCommitChanges(prefs) else {
            throw ProxyError.commitFailed
        }

        // Apply changes
        guard SCPreferencesApplyChanges(prefs) else {
            throw ProxyError.applyFailed
        }
    }

    private func removeSystemProxy() async throws {
        // Request authorization from user
        let authorized = try await AuthManager.shared.requestAuthorization()

        guard authorized else {
            throw ProxyError.authorizationDenied
        }

        // Get authorization reference
        guard let authRef = AuthManager.shared.getAuthorizationRef() else {
            throw ProxyError.authorizationFailed
        }

        // Create preferences with authorization
        guard let prefs = SCPreferencesCreateWithAuthorization(
            nil,
            "com.brick.app" as CFString,
            nil,
            authRef
        ) else {
            throw ProxyError.preferencesCreationFailed
        }

        // Lock preferences for modification
        guard SCPreferencesLock(prefs, true) else {
            throw ProxyError.lockFailed
        }

        defer {
            SCPreferencesUnlock(prefs)
        }

        // Get network services
        guard let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else {
            throw ProxyError.noNetworkServices
        }

        // Remove proxy configuration for each active network service
        for service in services {
            guard SCNetworkServiceGetEnabled(service) else {
                continue
            }

            guard let protocolSet = SCNetworkServiceCopyProtocols(service) as? [SCNetworkProtocol] else {
                continue
            }

            for networkProtocol in protocolSet {
                let type = SCNetworkProtocolGetProtocolType(networkProtocol)
                if type == kSCNetworkProtocolTypeIPv4 || type == kSCNetworkProtocolTypeIPv6 {
                    // Get proxies configuration
                    if let proxies = SCNetworkProtocolGetConfiguration(networkProtocol) as? [String: Any] {
                        var newProxies = proxies

                        // Disable PAC
                        newProxies[kCFNetworkProxiesProxyAutoConfigEnable as String] = 0
                        newProxies.removeValue(forKey: kCFNetworkProxiesProxyAutoConfigURLString as String)

                        // Set the new configuration
                        SCNetworkProtocolSetConfiguration(networkProtocol, newProxies as CFDictionary)
                    }
                }
            }
        }

        // Commit changes
        guard SCPreferencesCommitChanges(prefs) else {
            throw ProxyError.commitFailed
        }

        // Apply changes
        guard SCPreferencesApplyChanges(prefs) else {
            throw ProxyError.applyFailed
        }
    }
}

enum ProxyError: LocalizedError {
    case authorizationDenied
    case authorizationFailed
    case preferencesCreationFailed
    case lockFailed
    case noNetworkServices
    case commitFailed
    case applyFailed

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Authorization was denied. Site blocking requires admin privileges."
        case .authorizationFailed:
            return "Failed to obtain authorization."
        case .preferencesCreationFailed:
            return "Failed to create system preferences."
        case .lockFailed:
            return "Failed to lock system preferences."
        case .noNetworkServices:
            return "No network services found."
        case .commitFailed:
            return "Failed to commit changes to system preferences."
        case .applyFailed:
            return "Failed to apply changes to system preferences."
        }
    }
}
