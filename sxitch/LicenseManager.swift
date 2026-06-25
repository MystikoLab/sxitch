import Combine
import Foundation
import Security

// MARK: - Codable Models (mirrors Rust structs exactly)

private struct ActivateRequest: Encodable {
    let key: String
    let organization_id: String
    let label: String  // UUID string — mirrors Rust's `Uuid::new_v4()`
}

private struct LicenseKeyInfo: Decodable {
    let status: String
    let key: String
}

private struct ActivateResponse: Decodable {
    let id: String  // activation_id — stored in Keychain as "activation_id"
    let license_key_id: String
    let label: String
    let license_key: LicenseKeyInfo
}

private struct ValidateRequest: Encodable {
    let key: String
    let organization_id: String
    let activation_id: String
}

private struct ValidateResponse: Decodable {
    let id: String
    let organization_id: String
    let benefit_id: String
    let status: String
    let limit_activations: Int?
    let usage: Int
    let limit_usage: Int?
    let validations: Int
    let last_validated_at: String?
    let expires_at: String?
}

// MARK: - LicenseManager

@MainActor
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    // MARK: Published State

    @Published var isActivating: Bool = false
    @Published var activationMessage: String = ""
    @Published var isActivated: Bool = false

    // MARK: Constants — match Rust's POLAR_API_BASE / ORGANIZATION_ID / APP_NAME

    private let apiBase = "https://api.polar.sh/v1/customer-portal/license-keys"
    private let organizationId = "a2f08c52-6a41-4dc1-9b56-a5ea683b37b3"

    /// Keychain service name — matches Rust's `pub const APP_NAME: &str = "Sxitch"`
    private let keychainService = "Sxitch"

    private init() {}

    // MARK: - Public API

    /// Called on launch (and on each show when not Pro): loads Keychain credentials and
    /// silently re-validates against Polar.sh.
    ///
    /// Mirrors Rust's `Message::ValidateKey`:
    ///   - Skipped entirely in DEBUG builds (`option_env!("DEBUG_MODE")` equivalent)
    ///   - Skipped if Pro is already confirmed this session (avoids redundant API calls)
    ///   - Calls `validate_key(key_id, activation_id)` on success
    func checkStoredLicense() {
        #if DEBUG
            // Skip validation in debug — mirrors Rust's `option_env!("DEBUG_MODE").is_some()` guard.
            AppConfig.shared.isPro = true
            return
        #else
            // Already validated this session — no need to hit the network again.
            guard !AppConfig.shared.isPro else { return }
            guard let (activationId, keyId) = loadCredentials(), !keyId.isEmpty else { return }
            AppConfig.shared.licenseKey = keyId
            validate(key: keyId, activationId: activationId) { _ in }
        #endif
    }

    /// Activates a license key via POST `.../activate`.
    ///
    /// Request body mirrors `PolarKeyActivationReq`:
    /// `{ key, organization_id, label: UUID }`
    ///
    /// On success stores two Keychain entries — `activation_id` (`response.id`)
    /// and `key_id` (`response.license_key.key`) — then sets `AppConfig.isPro`.
    func activate(key: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            activationMessage = "Please enter a license key."
            completion(false, activationMessage)
            return
        }

        isActivating = true
        activationMessage = ""

        Task {
            defer { isActivating = false }

            guard let url = URL(string: "\(apiBase)/activate") else {
                activationMessage = "Invalid API URL."
                completion(false, activationMessage)
                return
            }

            // Fresh UUID label per activation — mirrors `label: Uuid::new_v4()`
            let body = ActivateRequest(
                key: trimmed,
                organization_id: organizationId,
                label: UUID().uuidString
            )

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                req.httpBody = try JSONEncoder().encode(body)
            } catch {
                activationMessage = "Failed to encode request."
                completion(false, activationMessage)
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: req)

                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    let detail = extractErrorDetail(from: data)
                    activationMessage = detail
                    completion(false, activationMessage)
                    return
                }

                let res = try JSONDecoder().decode(ActivateResponse.self, from: data)

                // Mirror: store_credentials(act_id, license_key.key)
                storeCredentials(activationId: res.id, keyId: res.license_key.key)

                let granted = res.license_key.status == "granted"
                AppConfig.shared.isPro = granted
                AppConfig.shared.licenseKey = res.license_key.key
                isActivated = granted

                if granted {
                    activationMessage = "License activated successfully!"
                    completion(true, activationMessage)
                } else {
                    activationMessage = "License status: \(res.license_key.status). Not granted."
                    completion(false, activationMessage)
                }
            } catch {
                activationMessage = error.localizedDescription
                completion(false, activationMessage)
            }
        }
    }

    /// Validates a stored license via POST `.../validate`.
    ///
    /// Request body mirrors `PolarKeyValidateReq`:
    /// `{ key, organization_id, activation_id }`
    ///
    /// Success criterion: `response.status == "granted"`.
    func validate(key: String, activationId: String, completion: @escaping (Bool) -> Void) {
        guard !key.isEmpty, !activationId.isEmpty else {
            AppConfig.shared.isPro = false
            isActivated = false
            completion(false)
            return
        }

        Task {
            guard let url = URL(string: "\(apiBase)/validate") else {
                AppConfig.shared.isPro = false
                completion(false)
                return
            }

            let body = ValidateRequest(
                key: key.trimmingCharacters(in: .whitespaces),
                organization_id: organizationId,
                activation_id: activationId
            )

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            guard let encoded = try? JSONEncoder().encode(body) else {
                AppConfig.shared.isPro = false
                completion(false)
                return
            }
            req.httpBody = encoded

            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let res = try JSONDecoder().decode(ValidateResponse.self, from: data)
                let granted = res.status == "granted"
                AppConfig.shared.isPro = granted
                isActivated = granted
                completion(granted)
            } catch {
                // Network failure — preserve existing Pro status rather than revoking
                completion(false)
            }
        }
    }

    /// Clears both Keychain entries and resets Pro status.
    /// Mirrors Rust's `delete_credentials()`.
    func deactivate() {
        deleteCredentials()
        AppConfig.shared.isPro = false
        AppConfig.shared.licenseKey = ""
        isActivated = false
        activationMessage = ""
    }

    // MARK: - Keychain Helpers

    /// Stores `activation_id` and `key_id` as separate Keychain entries.
    /// Mirrors Rust's `store_credentials(activation_id, key_id)`.
    private func storeCredentials(activationId: String, keyId: String) {
        saveKeychainItem(account: "activation_id", value: activationId)
        saveKeychainItem(account: "key_id", value: keyId)
    }

    /// Loads both credentials. Returns `nil` if either is missing.
    /// Mirrors Rust's `get_credentials() -> (activation_id, key_id)`.
    private func loadCredentials() -> (activationId: String, keyId: String)? {
        guard
            let activationId = loadKeychainItem(account: "activation_id"),
            let keyId = loadKeychainItem(account: "key_id"),
            !activationId.isEmpty, !keyId.isEmpty
        else { return nil }
        return (activationId, keyId)
    }

    /// Deletes both Keychain entries.
    /// Mirrors Rust's `delete_credentials()`.
    private func deleteCredentials() {
        deleteKeychainItem(account: "activation_id")
        deleteKeychainItem(account: "key_id")
    }

    private func saveKeychainItem(account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: account,
            kSecValueData: data,
        ]
        // Delete-then-add avoids errSecDuplicateItem
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: Keychain read with multi-service fallback
    //
    // The Rust APP_NAME constant (used as kSecAttrService) may differ in case
    // or form from what the Swift app expects.  macOS keychain service names are
    // case-sensitive, so "sxitch" != "Sxitch".  We try every plausible variant
    // and fall back to a service-agnostic search so we can find the item
    // regardless of what APP_NAME the Rust binary used.
    //
    // Check Console.app or the printed log lines to see the winning service name,
    // then update `keychainService` accordingly.
    private func loadKeychainItem(account: String) -> String? {
        // Ordered list of service-name candidates to try.
        // The Rust crate stores exactly APP_NAME as kSecAttrService.
        let candidates: [String] = [
            keychainService,  // "sxitch"
            keychainService.capitalized,  // "Sxitch"
            keychainService.uppercased(),  // "SXITCH"
            Bundle.main.bundleIdentifier ?? "",  // "com.umangsurana.sxitch"
        ].filter { !$0.isEmpty }

        for service in candidates {
            if let value = queryKeychain(service: service, account: account) {
                if service != keychainService {
                    print(
                        "[Sxitch Keychain] Found '\(account)' under service '\(service)' "
                            + "(expected '\(keychainService)') — update keychainService constant.")
                }
                return value
            }
        }

        // Last resort: search without a service filter so we pick up items
        // created by the Rust binary regardless of its APP_NAME.
        if let value = queryKeychain(service: nil, account: account) {
            print(
                "[Sxitch Keychain] Found '\(account)' with no service filter. "
                    + "Run: `security find-generic-password -a \(account) -g` "
                    + "in Terminal to see the exact service name and update keychainService.")
            return value
        }

        print("[Sxitch Keychain] Account '\(account)' not found in any candidate service.")
        return nil
    }

    /// Performs the actual SecItemCopyMatching call.  Pass `service: nil` to
    /// search across all services (useful for debugging / cross-app sharing).
    private func queryKeychain(service: String?, account: String) -> String? {
        // kSecUseAuthenticationUI / kSecUseAuthenticationUIAllow is the default on
        // macOS 11+ so we omit it to silence the deprecation warning.  The system
        // will still present a confirmation dialog if the item's ACL requires it.
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        if let service {
            query[kSecAttrService] = service
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil  // normal — just not stored under this service
        case errSecInteractionNotAllowed:
            print(
                "[Sxitch Keychain] errSecInteractionNotAllowed for '\(account)': "
                    + "the item exists but reading requires user confirmation and "
                    + "no UI is available right now. Will retry on next show.")
            return nil
        case errSecAuthFailed:
            print(
                "[Sxitch Keychain] errSecAuthFailed for '\(account)': "
                    + "the item's ACL does not trust this binary. "
                    + "Open Keychain Access > right-click the item > Get Info > Access Control "
                    + "and add the Sxitch.app binary to the trusted applications list.")
            return nil
        default:
            print("[Sxitch Keychain] Unexpected OSStatus \(status) for '\(account)'")
            return nil
        }
    }

    private func deleteKeychainItem(account: String) {
        // Delete from all candidate services so we don't leave orphans.
        let candidates: [String?] = [
            keychainService,
            keychainService.capitalized,
            Bundle.main.bundleIdentifier,
            nil,  // service-agnostic delete
        ]
        for service in candidates {
            var query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: account,
            ]
            if let service { query[kSecAttrService] = service }
            SecItemDelete(query as CFDictionary)
        }
    }

    // MARK: - Utilities

    private func extractErrorDetail(from data: Data) -> String {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return json["detail"] as? String
            ?? json["error"] as? String
            ?? "Activation failed."
    }
}
