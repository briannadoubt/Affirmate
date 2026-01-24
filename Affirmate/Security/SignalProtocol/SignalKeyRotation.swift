//
//  SignalKeyRotation.swift
//  Affirmate
//
//  Manages automatic rotation of Signal Protocol keys.
//

import Foundation
import os.log

// MARK: - Key Rotation Configuration

/// Configuration for automatic key rotation
struct KeyRotationConfiguration {
    /// How often to rotate the signed PreKey (default: 7 days)
    let signedPreKeyRotationInterval: TimeInterval
    /// Minimum number of one-time PreKeys before generating more
    let minimumOneTimePreKeyCount: Int
    /// Number of one-time PreKeys to generate when below minimum
    let oneTimePreKeyBatchSize: Int

    static let `default` = KeyRotationConfiguration(
        signedPreKeyRotationInterval: 7 * 24 * 60 * 60, // 7 days
        minimumOneTimePreKeyCount: 20,
        oneTimePreKeyBatchSize: 100
    )
}

// MARK: - Key Rotation Manager

/// Manages automatic rotation of Signal Protocol keys
actor SignalKeyRotationManager {

    private let logger = Logger(subsystem: "org.affirmate.signal", category: "key-rotation")
    private let configuration: KeyRotationConfiguration
    private var lastRotationDate: Date?
    private var rotationTask: Task<Void, Never>?

    init(configuration: KeyRotationConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Rotation Check

    /// Check if signed PreKey rotation is needed based on configuration
    func needsSignedPreKeyRotation() -> Bool {
        guard let lastRotation = lastRotationDate else {
            // Never rotated, should rotate
            return true
        }

        let timeSinceRotation = Date().timeIntervalSince(lastRotation)
        return timeSinceRotation >= configuration.signedPreKeyRotationInterval
    }

    /// Perform key rotation if needed
    func performRotationIfNeeded() async {
        do {
            // Check signed PreKey rotation
            if needsSignedPreKeyRotation() {
                logger.info("Rotating signed PreKey (interval: \(self.configuration.signedPreKeyRotationInterval)s)")
                let newSignedPreKey = try await SignalCrypto.shared.rotateSignedPreKey()

                // Upload to server
                try await uploadSignedPreKey(newSignedPreKey)

                lastRotationDate = Date()
                logger.info("Successfully rotated signed PreKey (id: \(newSignedPreKey.id))")
            }

            // Check one-time PreKey count
            let preKeyCount = try await getOneTimePreKeyCount()
            if preKeyCount < configuration.minimumOneTimePreKeyCount {
                logger.info("One-time PreKey count low (\(preKeyCount)/\(self.configuration.minimumOneTimePreKeyCount)), generating more")

                let newPreKeys = try await SignalCrypto.shared.generateAdditionalPreKeys(
                    count: configuration.oneTimePreKeyBatchSize
                )

                // Upload to server
                try await uploadOneTimePreKeys(newPreKeys)

                logger.info("Successfully generated and uploaded \(newPreKeys.count) new one-time PreKeys")
            }

        } catch {
            logger.error("Key rotation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Automatic Rotation

    /// Start automatic key rotation (checks daily)
    func startAutomaticRotation() {
        guard rotationTask == nil else {
            logger.warning("Automatic rotation already running")
            return
        }

        logger.info("Starting automatic key rotation (check interval: 24h)")

        rotationTask = Task {
            while !Task.isCancelled {
                await performRotationIfNeeded()

                // Check daily
                try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000) // 24 hours
            }
        }
    }

    /// Stop automatic key rotation
    func stopAutomaticRotation() {
        rotationTask?.cancel()
        rotationTask = nil
        logger.info("Stopped automatic key rotation")
    }

    // MARK: - Server Communication

    /// Upload signed PreKey to server
    private func uploadSignedPreKey(_ preKey: SignedPreKeyUpload) async throws {
        // This should call the actual API endpoint
        // For now, this is a placeholder that should be implemented based on your network layer
        logger.debug("Uploading signed PreKey to server (id: \(preKey.id))")

        // TODO: Implement actual server upload
        // Example:
        // let response = try await apiClient.post("/signal/keys/signed", body: preKey)
    }

    /// Upload one-time PreKeys to server
    private func uploadOneTimePreKeys(_ preKeys: [OneTimePreKeyUpload]) async throws {
        logger.debug("Uploading \(preKeys.count) one-time PreKeys to server")

        // TODO: Implement actual server upload
        // Example:
        // let response = try await apiClient.post("/signal/keys/onetime", body: preKeys)
    }

    /// Get current one-time PreKey count from server
    private func getOneTimePreKeyCount() async throws -> Int {
        // TODO: Implement actual server query
        // Example:
        // let response = try await apiClient.get("/signal/keys/count")
        // return response.count

        // Placeholder
        return 50
    }

    // MARK: - Manual Rotation

    /// Manually trigger signed PreKey rotation
    func rotateSignedPreKeyNow() async throws {
        logger.info("Manual signed PreKey rotation triggered")
        let newSignedPreKey = try await SignalCrypto.shared.rotateSignedPreKey()
        try await uploadSignedPreKey(newSignedPreKey)
        lastRotationDate = Date()
        logger.info("Manual signed PreKey rotation completed (id: \(newSignedPreKey.id))")
    }

    /// Manually generate and upload one-time PreKeys
    func generateOneTimePreKeysNow(count: Int) async throws {
        logger.info("Manual one-time PreKey generation triggered (count: \(count))")
        let newPreKeys = try await SignalCrypto.shared.generateAdditionalPreKeys(count: count)
        try await uploadOneTimePreKeys(newPreKeys)
        logger.info("Manual one-time PreKey generation completed (\(newPreKeys.count) keys)")
    }

    // MARK: - Testing Support

    /// Set last rotation date (for testing)
    func setLastRotationDate(_ date: Date) {
        self.lastRotationDate = date
    }
}
