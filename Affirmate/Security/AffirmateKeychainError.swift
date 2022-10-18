//
//  AffirmateKeychainError.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import Foundation

enum AffirmateKeychainError: LocalizedError {
    
    case failedToGenerateIdentity
    case identityNotFound
    case sessionNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedToGenerateIdentity:
            return "Failed to generate a new secure identity."
        case .identityNotFound:
            return "The current user does not have a secure identity. Generate a new identity key pair for this user/device."
        case .sessionNotFound:
            return "The cryptographic session has not been set up for encryption/decryption."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .failedToGenerateIdentity:
            return "Please sign out, restart the app, and try again."
        case .identityNotFound:
            return "The user's signature idenity is invalid. Please uninstall and reinstall the app."
        case .sessionNotFound:
            return "Session not found, please reload the chat."
        }
    }
}
