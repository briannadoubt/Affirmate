//
//  AffirmateKeychain.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case unexpectedItemData
    case stringEncodingFailure
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedItemData:
            return "The stored keychain item does not contain the expected data payload."
        case .stringEncodingFailure:
            return "Unable to decode keychain item as a UTF-8 string."
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain operation failed with status: \(status)."
        }
    }
}

final nonisolated class AffirmateKeychain: Sendable {

    static let appIdentifierPrefix = Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String ?? ""
    static let chatService = "\(appIdentifierPrefix)org.affirmate.chat"
    static let sessionService = "\(appIdentifierPrefix)org.affirmate.session"
    static let accessGroup = "group.Affirmate"

    static let chat: Keychain = Keychain(
        service: chatService,
        accessGroup: accessGroup,
        synchronizable: true
    )

    static let session: Keychain = Keychain(
        service: sessionService,
        accessGroup: accessGroup,
        synchronizable: true
    )
}

nonisolated struct Keychain: Sendable {

    enum Accessibility: Sendable {
        case afterFirstUnlock
        case afterFirstUnlockThisDeviceOnly
        case whenUnlocked
        case whenUnlockedThisDeviceOnly

        var secValue: CFString {
            switch self {
            case .afterFirstUnlock:
                return kSecAttrAccessibleAfterFirstUnlock
            case .afterFirstUnlockThisDeviceOnly:
                return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whenUnlocked:
                return kSecAttrAccessibleWhenUnlocked
            case .whenUnlockedThisDeviceOnly:
                return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            }
        }
    }

    struct Configuration: Sendable {
        var service: String?
        var accessGroup: String?
        var synchronizable: Bool
        var accessibility: Accessibility
    }

    private let configuration: Configuration

    init(
        service: String? = Keychain.defaultService,
        accessGroup: String? = nil,
        synchronizable: Bool = false,
        accessibility: Accessibility = .afterFirstUnlock
    ) {
        self.configuration = Configuration(
            service: service,
            accessGroup: accessGroup,
            synchronizable: synchronizable,
            accessibility: accessibility
        )
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var service: String? { configuration.service }
    var accessGroup: String? { configuration.accessGroup }
    var synchronizable: Bool { configuration.synchronizable }
    var accessibility: Accessibility { configuration.accessibility }

    subscript(key: String) -> String? {
        get { self[string: key] }
        set { self[string: key] = newValue }
    }

    subscript(string key: String) -> String? {
        get { try? getString(key) }
        set {
            if let newValue {
                try? set(newValue, key: key)
            } else {
                _ = try? remove(key)
            }
        }
    }

    subscript(data key: String) -> Data? {
        get { try? getData(key) }
        set {
            if let newValue {
                try? set(newValue, key: key)
            } else {
                _ = try? remove(key)
            }
        }
    }

    func set(_ value: String, key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.stringEncodingFailure
        }
        try set(data, key: key)
    }

    func set(_ data: Data, key: String) throws {
        try performAddOrUpdate(data: data, for: key)
    }

    func getString(_ key: String) throws -> String? {
        guard let data = try getData(key) else {
            return nil
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.stringEncodingFailure
        }
        return value
    }

    func getData(_ key: String) throws -> Data? {
        var query = baseQuery(account: key)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true

        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecItemNotFound:
            return nil
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainError.unexpectedItemData
            }
            return data
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    @discardableResult
    func remove(_ key: String) throws -> Bool {
        let status = SecItemDelete(baseQuery(account: key) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return true
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    @discardableResult
    func removeAll() throws -> Bool {
        let status = SecItemDelete(baseQuery(account: nil) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return true
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func performAddOrUpdate(data: Data, for key: String) throws {
        var query = baseQuery(account: key)
        query[kSecValueData] = data
        query[kSecAttrAccessible] = configuration.accessibility.secValue

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributesToUpdate: [CFString: Any] = [
                kSecValueData: data
            ]
            let updateStatus = SecItemUpdate(baseQuery(account: key) as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(updateStatus)
            }
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery(account: String?) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword
        ]
        if let account {
            query[kSecAttrAccount] = account
        }
        if let service = configuration.service {
            query[kSecAttrService] = service
        }
        if let accessGroup = configuration.accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        if configuration.synchronizable {
            query[kSecAttrSynchronizable] = true
        }
        return query
    }

    private static let defaultService: String = {
        if let identifier = Bundle.main.bundleIdentifier {
            return identifier
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return bundleName
        }
        return "org.affirmate.keychain"
    }()
}
