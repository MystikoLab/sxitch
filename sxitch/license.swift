//
//  license.swift
//  sxitch
//
//  Created by Umang on 26/6/26.
//

import Foundation
import Security

let APP_NAME = "Sxitch"
private let POLAR_API_BASE = "https://api.polar.sh/v1/customer-portal/license-keys"
private let ORGANIZATION_ID = "a2f08c52-6a41-4dc1-9b56-a5ea683b37b3"

struct PolarKeyActivationReq: Encodable {
    let key: String
    let organizationId: String
    let label: UUID

    enum CodingKeys: String, CodingKey {
        case key
        case organizationId = "organization_id"
        case label
    }
}

struct LicenseKey: Decodable {
    let status: String
    let key: String
}

struct PolarKeyActivationRes: Decodable {
    let id: String
    let licenseKeyId: String
    let label: String
    let licenseKey: LicenseKey

    enum CodingKeys: String, CodingKey {
        case id
        case licenseKeyId = "license_key_id"
        case label
        case licenseKey = "license_key"
    }
}

struct PolarKeyValidateReq: Encodable {
    let key: String
    let organizationId: String
    let activationId: String

    enum CodingKeys: String, CodingKey {
        case key
        case organizationId = "organization_id"
        case activationId = "activation_id"
    }
}

struct Activation: Decodable {
    let id: String
    let licenseKeyId: String

    enum CodingKeys: String, CodingKey {
        case id
        case licenseKeyId = "license_key_id"
    }
}

struct PolarKeyValidateRes: Decodable {
    let id: String
    let organizationId: String
    let benefitId: String
    let status: String
    let limitActivations: UInt32?
    let usage: UInt32
    let limitUsage: UInt32?
    let validations: UInt32
    let lastValidatedAt: String?
    let expiresAt: String?
    let activation: Activation?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationId = "organization_id"
        case benefitId = "benefit_id"
        case status
        case limitActivations = "limit_activations"
        case usage
        case limitUsage = "limit_usage"
        case validations
        case lastValidatedAt = "last_validated_at"
        case expiresAt = "expires_at"
        case activation
    }
}

func activateKey(key: String) async throws -> Bool {
    let reqBody = PolarKeyActivationReq(
        key: key,
        organizationId: ORGANIZATION_ID,
        label: UUID()
    )

    guard let url = URL(string: "\(POLAR_API_BASE)/activate") else {
        return false
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(reqBody)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
        return false
    }

    let body = try JSONDecoder().decode(PolarKeyActivationRes.self, from: data)

    let actId = body.id
    let licenseKeyId = body.licenseKey.key

    do {
        try storeCredentials(activationId: actId, keyId: licenseKeyId)
        print("Credentials stored successfully") // Replace with your preferred Swift logger
    } catch {
        print("Failed to store credentials: \(error)")
    }

    return body.licenseKey.status == "granted"
}

func validateKey(key: String, activationId: String) async throws -> Bool {
    let reqBody = PolarKeyValidateReq(
        key: key.trimmingCharacters(in: .whitespacesAndNewlines),
        organizationId: ORGANIZATION_ID,
        activationId: activationId
    )

    guard let url = URL(string: "\(POLAR_API_BASE)/validate") else {
        return false
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(reqBody)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
        return false
    }

    let body = try JSONDecoder().decode(PolarKeyValidateRes.self, from: data)
    return body.status == "granted"
}

// MARK: - Keychain Service Helpers (Keyring Alternative)

enum KeychainError: Error {
    case conversionError
    case unhandledStatus(OSStatus)
}

func storeCredentials(activationId: String, keyId: String) throws {
    try saveKeychainSecret(account: "activation_id", secret: activationId)
    try saveKeychainSecret(account: "key_id", secret: keyId)
}

func getCredentials() throws -> (String, String) {
    let activationId = try readKeychainSecret(account: "activation_id")
    let keyId = try readKeychainSecret(account: "key_id")
    return (activationId, keyId)
}

func deleteCredentials() throws {
    try deleteKeychainSecret(account: "activation_id")
    try deleteKeychainSecret(account: "key_id")
}

// MARK: - Low-Level Keychain Operations

private func saveKeychainSecret(account: String, secret: String) throws {
    guard let data = secret.data(withAllowedCharacters: .utf8) else {
        throw KeychainError.conversionError
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: APP_NAME,
        kSecAttrAccount as String: account,
        kSecValueData as String: data,
    ]

    // First try to delete existing item to handle updates cleanly
    SecItemDelete(query as CFDictionary)

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.unhandledStatus(status)
    }
}

private func readKeychainSecret(account: String) throws -> String {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: APP_NAME,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var dataTypeRef: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

    guard status == errSecSuccess, let data = dataTypeRef as? Data else {
        throw KeychainError.unhandledStatus(status)
    }

    guard let secret = String(data: data, encoding: .utf8) else {
        throw KeychainError.conversionError
    }

    return secret
}

private func deleteKeychainSecret(account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: APP_NAME,
        kSecAttrAccount as String: account,
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw KeychainError.unhandledStatus(status)
    }
}

/// Swift Data extension helper
private extension String {
    func data(withAllowedCharacters encoding: String.Encoding) -> Data? {
        return data(using: encoding)
    }
}
