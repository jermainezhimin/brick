import Foundation
import Security

@MainActor
class AuthManager {
    static let shared = AuthManager()

    private var authorizationRef: AuthorizationRef?

    private init() {}

    func requestAuthorization() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var authRef: AuthorizationRef?

                // Create authorization
                var status = AuthorizationCreate(nil, nil, [], &authRef)

                guard status == errAuthorizationSuccess else {
                    continuation.resume(returning: false)
                    return
                }

                // Define the rights we need
                // Use a custom right name
                let rightName = "system.preferences"

                status = rightName.withCString { namePtr in
                    var authItem = AuthorizationItem(
                        name: namePtr,
                        valueLength: 0,
                        value: nil,
                        flags: 0
                    )

                    var authRights = AuthorizationRights(
                        count: 1,
                        items: withUnsafeMutablePointer(to: &authItem) { $0 }
                    )

                    // Request authorization with interaction allowed
                    let flags: AuthorizationFlags = [
                        .interactionAllowed,
                        .extendRights,
                        .preAuthorize
                    ]

                    return AuthorizationCopyRights(
                        authRef!,
                        &authRights,
                        nil,
                        flags,
                        nil
                    )
                }

                if status == errAuthorizationSuccess {
                    Task { @MainActor in
                        self.authorizationRef = authRef
                        continuation.resume(returning: true)
                    }
                } else {
                    if let authRef = authRef {
                        AuthorizationFree(authRef, [])
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func getAuthorizationRef() -> AuthorizationRef? {
        return authorizationRef
    }

    deinit {
        if let authRef = authorizationRef {
            AuthorizationFree(authRef, [])
        }
    }
}
